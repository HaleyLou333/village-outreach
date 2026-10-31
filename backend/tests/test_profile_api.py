import json
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, func, select

from app.auth import dependencies
from app.database.session import get_session
from app.main import app
from app.models import User
from tests.auth_helpers import encode

pytestmark = pytest.mark.database


@pytest.fixture
def profile_client(db_session, verifier, monkeypatch):
    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_session] = lambda: db_session
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)


def auth_headers(claims, signing_key):
    return {"Authorization": "Bearer " + encode(claims, signing_key)}


def test_read_own_profile_provisions_once_and_returns_public_contract(
    profile_client, db_session, claims, signing_key
):
    headers = auth_headers(claims, signing_key)
    first = profile_client.get("/users/me", headers=headers)
    assert first.status_code == 200
    body = first.json()
    assert set(body) == {
        "id",
        "email",
        "display_name",
        "role",
        "status",
        "created_at",
        "updated_at",
    }
    assert UUID(body["id"])
    assert body["email"] == "neighbor@example.com"
    assert body["display_name"] == "Neighbor"
    assert body["role"] == "neighbor"
    assert body["status"] == "active"
    assert body["created_at"].endswith("Z")
    second = profile_client.get("/users/me", headers=headers)
    assert second.json() == body
    assert db_session.scalar(select(func.count()).select_from(User)) == 1


def test_update_persists_and_does_not_touch_another_users_profile(
    profile_client, db_session, claims, signing_key
):
    other = User(supabase_uid=uuid4(), email="other@example.com", display_name="Other")
    db_session.add(other)
    db_session.commit()
    other_id = other.id
    headers = auth_headers(claims, signing_key)
    before = profile_client.get("/users/me", headers=headers).json()
    changed = profile_client.patch(
        "/users/me",
        headers=headers,
        json={"display_name": "  Eric Reyes  "},
        params={"user_id": str(other_id)},
    )
    assert changed.status_code == 200
    assert changed.json()["display_name"] == "Eric Reyes"
    assert changed.json()["id"] == before["id"]
    assert changed.json()["created_at"] == before["created_at"]
    assert changed.json()["updated_at"] >= before["updated_at"]
    db_session.expunge_all()
    persisted = profile_client.get("/users/me", headers=headers)
    assert persisted.json() == changed.json()
    assert db_session.get(User, other_id).display_name == "Other"
    assert profile_client.get(f"/users/{other_id}", headers=headers).status_code == 404


@pytest.mark.parametrize("name", ["", "   ", "x" * 101, None, 123, [], "bad\u0000name", "\ud800"])
def test_invalid_update_rejected_without_changing_profile(
    profile_client, claims, signing_key, name
):
    headers = auth_headers(claims, signing_key)
    before = profile_client.get("/users/me", headers=headers).json()
    response = profile_client.patch(
        "/users/me",
        headers={**headers, "Content-Type": "application/json"},
        content=json.dumps({"display_name": name}),
    )
    assert response.status_code == 422
    assert profile_client.get("/users/me", headers=headers).json() == before


@pytest.mark.parametrize(
    "field,value",
    [
        ("id", "00000000-0000-0000-0000-000000000001"),
        ("supabase_uid", "00000000-0000-0000-0000-000000000001"),
        ("email", "attacker@example.com"),
        ("role", "admin"),
        ("status", "active"),
        ("created_at", "2026-01-01T00:00:00Z"),
        ("updated_at", "2026-01-01T00:00:00Z"),
        ("unknown", "value"),
    ],
)
def test_protected_or_unknown_fields_rejected_atomically(
    profile_client, claims, signing_key, field, value
):
    headers = auth_headers(claims, signing_key)
    before = profile_client.get("/users/me", headers=headers).json()
    response = profile_client.patch(
        "/users/me", headers=headers, json={"display_name": "Changed", field: value}
    )
    assert response.status_code == 422
    assert profile_client.get("/users/me", headers=headers).json() == before


def test_empty_update_rejected(profile_client, claims, signing_key):
    response = profile_client.patch("/users/me", headers=auth_headers(claims, signing_key), json={})
    assert response.status_code == 422


def test_display_name_accepts_100_unicode_characters(profile_client, claims, signing_key):
    name = "\u00e9" * 100
    response = profile_client.patch(
        "/users/me",
        headers=auth_headers(claims, signing_key),
        json={"display_name": "  " + name + "  "},
    )
    assert response.status_code == 200
    assert response.json()["display_name"] == name


def test_two_signed_in_users_read_and_update_only_their_own_profiles(
    profile_client, claims, signing_key
):
    first_headers = auth_headers(claims, signing_key)
    second_claims = {**claims, "sub": str(uuid4()), "email": "second@example.com"}
    second_headers = auth_headers(second_claims, signing_key)
    first = profile_client.get("/users/me", headers=first_headers).json()
    second = profile_client.get("/users/me", headers=second_headers).json()
    assert first["id"] != second["id"]
    response = profile_client.patch(
        "/users/me",
        headers=second_headers,
        json={"display_name": "Second Neighbor"},
        params={"id": first["id"]},
    )
    assert response.status_code == 200
    assert response.json()["id"] == second["id"]
    assert profile_client.get("/users/me", headers=first_headers).json() == first


@pytest.mark.parametrize("change", ["deleted", "suspended"])
def test_update_rechecks_profile_after_authentication(profile_client, db_session, change):
    existing = User(supabase_uid=uuid4(), email="neighbor@example.com", display_name="Existing")
    db_session.add(existing)
    db_session.commit()
    stale = User(id=existing.id, status="active")
    if change == "deleted":
        db_session.execute(delete(User).where(User.id == existing.id))
    else:
        existing.status = "suspended"
    db_session.commit()
    app.dependency_overrides[dependencies.get_current_user] = lambda: stale
    response = profile_client.patch("/users/me", json={"display_name": "Changed"})
    assert response.status_code == (404 if change == "deleted" else 403)
    if change == "deleted":
        assert response.json() == {"detail": "Profile not found."}
    else:
        db_session.refresh(existing)
        assert existing.display_name == "Existing"


def test_invalid_body_error_does_not_echo_profile_input(profile_client, claims, signing_key):
    response = profile_client.patch(
        "/users/me",
        headers=auth_headers(claims, signing_key),
        json={"display_name": "private-value", "email": "private@example.com"},
    )
    assert response.status_code == 422
    assert response.json() == {"detail": "Invalid request data."}


@pytest.mark.parametrize("method", ["get", "patch"])
def test_profile_requires_authentication(profile_client, db_session, method):
    options = {"json": {"display_name": "Neighbor"}} if method == "patch" else {}
    response = getattr(profile_client, method)("/users/me", **options)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert db_session.scalar(select(func.count()).select_from(User)) == 0


@pytest.mark.parametrize("status", ["inactive", "suspended"])
@pytest.mark.parametrize("method", ["get", "patch"])
def test_inactive_account_cannot_read_or_update(
    profile_client, db_session, claims, signing_key, status, method
):
    user = User(
        supabase_uid=UUID(claims["sub"]),
        email=claims["email"],
        display_name="Existing",
        status=status,
    )
    db_session.add(user)
    db_session.commit()
    options = {"json": {"display_name": "Changed"}} if method == "patch" else {}
    response = getattr(profile_client, method)(
        "/users/me", headers=auth_headers(claims, signing_key), **options
    )
    assert response.status_code == 403
    db_session.refresh(user)
    assert user.display_name == "Existing"


def test_openapi_describes_authenticated_profile_routes(profile_client):
    spec = profile_client.get("/openapi.json").json()
    for method in ("get", "patch"):
        assert spec["paths"]["/users/me"][method]["security"] == [{"HTTPBearer": []}]


def test_failed_profile_save_rolls_back_with_generic_503(
    profile_client, db_session, claims, signing_key, monkeypatch
):
    from sqlalchemy.exc import OperationalError

    headers = auth_headers(claims, signing_key)
    before = profile_client.get("/users/me", headers=headers).json()

    def failed_commit():
        raise OperationalError("private SQL", {}, RuntimeError("private database error"))

    monkeypatch.setattr(db_session, "commit", failed_commit)
    response = profile_client.patch("/users/me", headers=headers, json={"display_name": "Changed"})
    assert response.status_code == 503
    assert "private" not in response.text
    assert profile_client.get("/users/me", headers=headers).json() == before
