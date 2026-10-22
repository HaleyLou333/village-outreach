from uuid import uuid4

import pytest
from sqlalchemy import UniqueConstraint, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database.base import Base
from app.models import User


def test_user_identity_contract_matches_the_sdd():
    table = User.__table__
    assert table.schema == "app_private"
    assert table.fullname in Base.metadata.tables
    assert set(table.columns.keys()) == {
        "id",
        "supabase_uid",
        "email",
        "display_name",
        "role",
        "status",
        "created_at",
        "updated_at",
    }
    assert all(not column.nullable for column in table.columns)
    assert "password" not in table.columns
    assert any(
        isinstance(constraint, UniqueConstraint)
        and list(constraint.columns.keys()) == ["supabase_uid"]
        for constraint in table.constraints
    )
    assert table.c.created_at.type.timezone
    assert table.c.updated_at.type.timezone
    user = User(supabase_uid=uuid4(), email="neighbor@example.com", display_name="Neighbor")
    assert user.supabase_uid is not None


@pytest.mark.database
def test_user_save_reload_and_utc_timestamps(db_session):
    user = User(supabase_uid=uuid4(), email="neighbor@example.com", display_name="Neighbor")
    db_session.add(user)
    db_session.commit()
    identity = user.id
    db_session.expunge_all()
    loaded = db_session.get(User, identity)
    assert loaded.email == "neighbor@example.com"
    assert loaded.role == "neighbor"
    assert loaded.status == "active"
    assert loaded.created_at.utcoffset().total_seconds() == 0
    assert loaded.updated_at.utcoffset().total_seconds() == 0


@pytest.mark.database
def test_duplicate_supabase_identity_rejected(db_session):
    identity = uuid4()
    db_session.add(User(supabase_uid=identity, email="a@example.com", display_name="A"))
    db_session.flush()
    db_session.add(User(supabase_uid=identity, email="b@example.com", display_name="B"))
    with pytest.raises(IntegrityError):
        db_session.flush()


@pytest.mark.database
@pytest.mark.parametrize("field", ["supabase_uid", "email", "display_name"])
def test_missing_required_fields_rejected(db_session, field):
    values = {"supabase_uid": uuid4(), "email": "a@example.com", "display_name": "A"}
    values[field] = None
    db_session.add(User(**values))
    with pytest.raises(IntegrityError):
        db_session.flush()


@pytest.mark.database
@pytest.mark.parametrize(
    "field,value",
    [
        ("role", "root"),
        ("status", "unknown"),
        ("email", " "),
        ("display_name", " "),
        ("email", "x" * 255),
        ("display_name", "x" * 101),
    ],
)
def test_profile_constraints_rejected(db_session, field, value):
    values = {"supabase_uid": uuid4(), "email": "a@example.com", "display_name": "A"}
    values[field] = value
    db_session.add(User(**values))
    with pytest.raises(IntegrityError):
        db_session.flush()


@pytest.mark.database
def test_fixture_rolls_back_even_committed_test_records(db_engine):
    identity = uuid4()
    with db_engine.connect() as connection:
        transaction = connection.begin()
        with Session(bind=connection, join_transaction_mode="create_savepoint") as session:
            session.add(User(supabase_uid=identity, email="a@example.com", display_name="A"))
            session.commit()
        transaction.rollback()
    with Session(db_engine) as fresh:
        assert (
            fresh.scalar(
                select(func.count()).select_from(User).where(User.supabase_uid == identity)
            )
            == 0
        )
