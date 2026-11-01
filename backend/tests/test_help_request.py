from uuid import uuid4

import pytest
from sqlalchemy import delete, insert, select, text
from sqlalchemy.exc import IntegrityError

from app import models
from app.models import User

pytestmark = pytest.mark.database


@pytest.fixture
def requester(db_session):
    user = User(supabase_uid=uuid4(), email="requester@example.com", display_name="Requester")
    db_session.add(user)
    db_session.flush()
    return user


def request_values(requester_id):
    return dict(
        requester_id=requester_id,
        title="Groceries needed",
        description="Help carrying groceries from the local store.",
        category="FOOD_ASSISTANCE",
        urgency="standard",
        latitude=35.4,
        longitude=-97.5,
        area="Central neighborhood",
        idempotency_key="test-operation",
        creation_hash="a" * 64,
    )


def test_help_request_model_is_registered():
    assert hasattr(models, "HelpRequest"), "HelpRequest must be registered for migrations"


def test_save_reload_requester_and_utc_defaults(db_session, requester):
    request = models.HelpRequest(**request_values(requester.id))
    db_session.add(request)
    db_session.commit()
    identity = request.id
    owner_id = requester.id
    db_session.expunge_all()
    loaded = db_session.get(models.HelpRequest, identity)
    assert loaded.requester.id == owner_id
    assert loaded.title == "Groceries needed"
    assert loaded.status == "active"
    assert loaded.created_at.utcoffset().total_seconds() == 0
    assert loaded.updated_at.utcoffset().total_seconds() == 0
    previous = loaded.updated_at
    # now() is transaction scoped; an explicit older value makes the ORM update
    # behavior observable without sleeping or crossing fixture transactions.
    db_session.execute(
        text("UPDATE app_private.help_requests SET updated_at = '2000-01-01 UTC' WHERE id=:id"),
        {"id": identity},
    )
    db_session.refresh(loaded)
    loaded.title = "Groceries collected"
    db_session.flush()
    db_session.refresh(loaded)
    assert loaded.updated_at >= previous


@pytest.mark.parametrize(
    "field",
    [
        "requester_id",
        "title",
        "description",
        "category",
        "urgency",
        "latitude",
        "longitude",
        "area",
        "idempotency_key",
        "creation_hash",
        "status",
        "created_at",
        "updated_at",
    ],
)
def test_required_request_fields_rejected_by_database(db_session, requester, field):
    values = request_values(requester.id)
    values[field] = None
    with pytest.raises(IntegrityError):
        db_session.execute(insert(models.HelpRequest).values(**values))


@pytest.mark.parametrize(
    "field,value",
    [
        ("title", ""),
        ("title", " "),
        ("title", "\u2003"),
        ("title", "x" * 121),
        ("description", ""),
        ("description", "x" * 4001),
        ("area", ""),
        ("area", "x" * 101),
        ("category", "OTHER"),
        ("urgency", "urgent"),
        ("status", "reopened"),
        ("latitude", -90.01),
        ("latitude", 90.01),
        ("longitude", -180.01),
        ("longitude", 180.01),
        ("latitude", float("nan")),
        ("longitude", float("nan")),
        ("latitude", float("inf")),
        ("longitude", float("-inf")),
        ("idempotency_key", ""),
        ("idempotency_key", "x" * 129),
        ("creation_hash", "a" * 63),
        ("creation_hash", "z" * 64),
    ],
)
def test_invalid_request_values_rejected_by_database(db_session, requester, field, value):
    values = request_values(requester.id)
    values[field] = value
    with pytest.raises(IntegrityError):
        db_session.execute(insert(models.HelpRequest).values(**values))


def test_missing_requester_and_owner_deletion_rejected(db_session, requester):
    values = request_values(uuid4())
    with pytest.raises(IntegrityError), db_session.begin_nested():
        db_session.execute(insert(models.HelpRequest).values(**values))
    db_session.execute(insert(models.HelpRequest).values(**request_values(requester.id)))
    with pytest.raises(IntegrityError):
        db_session.execute(delete(User).where(User.id == requester.id))


def test_idempotency_key_is_unique_per_requester(db_session, requester):
    values = request_values(requester.id)
    db_session.execute(insert(models.HelpRequest).values(**values))
    with pytest.raises(IntegrityError), db_session.begin_nested():
        db_session.execute(insert(models.HelpRequest).values(**values))
    other = User(supabase_uid=uuid4(), email="other@example.com", display_name="Other")
    db_session.add(other)
    db_session.flush()
    db_session.execute(insert(models.HelpRequest).values(**request_values(other.id)))
    assert len(db_session.scalars(select(models.HelpRequest)).all()) == 2


@pytest.mark.parametrize("latitude,longitude", [(-90, -180), (90, 180), (0, 0)])
def test_coordinate_boundaries_and_server_generated_identity(
    db_session, requester, latitude, longitude
):
    values = request_values(requester.id) | {"latitude": latitude, "longitude": longitude}
    identity = db_session.scalar(
        text("""
            INSERT INTO app_private.help_requests
                (requester_id, title, description, category, urgency, latitude, longitude,
                 area, idempotency_key, creation_hash)
            VALUES (:requester_id, :title, :description, :category, :urgency, :latitude,
                    :longitude, :area, :idempotency_key, :creation_hash)
            RETURNING id
        """),
        values,
    )
    assert identity is not None
    assert db_session.get(models.HelpRequest, identity).latitude == latitude
