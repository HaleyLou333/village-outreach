from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from typing import Annotated
from uuid import uuid4

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import delete, event, func, select
from sqlalchemy.orm import Session

from app.auth.tokens import VerifiedIdentity
from app.database.session import get_session
from app.models import User
from tests.auth_helpers import encode

pytestmark = pytest.mark.database


@pytest.fixture
def identity():
    return VerifiedIdentity(uuid4(), "neighbor@example.com", "New Neighbor")


def test_repeated_access_links_exactly_one_profile(db_session, identity):
    from app.auth.profiles import resolve_user

    first = resolve_user(db_session, identity)
    second = resolve_user(db_session, identity)
    assert first.id == second.id
    assert first.supabase_uid == identity.subject
    assert first.role == "neighbor"
    assert first.status == "active"
    assert db_session.scalar(select(func.count()).select_from(User)) == 1


def test_existing_profile_preserves_server_fields(db_session, identity):
    from app.auth.profiles import resolve_user

    existing = User(
        supabase_uid=identity.subject,
        email="old@example.com",
        display_name="Existing Name",
        role="moderator",
    )
    db_session.add(existing)
    db_session.commit()
    user = resolve_user(db_session, identity)
    assert user.id == existing.id
    assert user.email == "old@example.com"
    assert user.display_name == "Existing Name"
    assert user.role == "moderator"


def test_same_email_does_not_link_different_subjects(db_session, identity):
    from app.auth.profiles import resolve_user

    first = resolve_user(db_session, identity)
    second = resolve_user(
        db_session, VerifiedIdentity(uuid4(), identity.email, identity.display_name)
    )
    assert first.id != second.id


def test_signed_access_provisions_profile_and_ignores_caller_identity(
    db_session, verifier, claims, signing_key, monkeypatch
):
    from app.auth import dependencies
    from app.auth.dependencies import get_current_user

    app = FastAPI()

    @app.get("/protected")
    def protected(user: Annotated[User, Depends(get_current_user)]):
        return {"id": str(user.id), "role": user.role, "subject": str(user.supabase_uid)}

    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    app.dependency_overrides[get_session] = lambda: db_session
    with TestClient(app) as client:
        missing = client.get("/protected")
        assert missing.status_code == 401
        assert db_session.scalar(select(func.count()).select_from(User)) == 0
        headers = {"Authorization": "Bearer " + encode(claims, signing_key)}
        first = client.get("/protected", headers=headers, params={"user_id": str(uuid4())})
        second = client.get("/protected", headers=headers)
    assert first.status_code == 200
    assert first.json() == second.json()
    assert first.json()["subject"] == claims["sub"]
    assert first.json()["role"] == "neighbor"
    assert db_session.scalar(select(func.count()).select_from(User)) == 1


def test_concurrent_first_access_creates_one_profile(db_engine, identity):
    from app.auth.profiles import resolve_user

    barrier = Barrier(2)

    def synchronize_insert(connection, cursor, statement, parameters, context, executemany):
        if statement.startswith("INSERT INTO app_private.users"):
            # Both initial SELECTs must finish before either insert can proceed.
            barrier.wait(timeout=10)

    def sign_in():
        with Session(db_engine) as session:
            return resolve_user(session, identity).id

    event.listen(db_engine, "before_cursor_execute", synchronize_insert)
    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            ids = list(executor.map(lambda _: sign_in(), range(2)))
        assert ids[0] == ids[1]
        with Session(db_engine) as session:
            assert (
                session.scalar(
                    select(func.count())
                    .select_from(User)
                    .where(User.supabase_uid == identity.subject)
                )
                == 1
            )
    finally:
        event.remove(db_engine, "before_cursor_execute", synchronize_insert)
        with db_engine.begin() as connection:
            connection.execute(delete(User).where(User.supabase_uid == identity.subject))


@pytest.mark.parametrize("status", ["active", "inactive", "suspended"])
def test_protected_user_dependency_enforces_application_status(db_session, identity, status):
    from app.auth.dependencies import get_current_user, get_verified_identity

    existing = User(
        supabase_uid=identity.subject,
        email=identity.email,
        display_name="Neighbor",
        status=status,
    )
    db_session.add(existing)
    db_session.commit()
    app = FastAPI()

    @app.get("/protected")
    def protected(user: Annotated[User, Depends(get_current_user)]):
        return {"id": str(user.id)}

    app.dependency_overrides[get_session] = lambda: db_session
    app.dependency_overrides[get_verified_identity] = lambda: identity
    with TestClient(app) as client:
        response = client.get("/protected", params={"user_id": str(uuid4()), "role": "admin"})
    assert response.status_code == (200 if status == "active" else 403)
    if status == "active":
        assert response.json() == {"id": str(existing.id)}
