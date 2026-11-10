"""The curated resource import is repeatable and preserves maintenance edits."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import func, select

from app.models import Resource
from app.schemas.resources import ResourceQuery
from app.services.resources import list_resources

pytestmark = pytest.mark.database


def test_curated_seed_is_repeatable_without_reenabling_listings(db_session):
    from scripts.seed_resources import load_seed, seed_resources

    records = load_seed()
    assert len(records) >= 10
    assert {record.area for record in records} == {"Oklahoma City Metro"}
    # Keep the visibility check independent of the real listings' expiration date.
    now = datetime.now(UTC)
    records = [record.model_copy(update={"last_verified_at": now}) for record in records]
    assert seed_resources(db_session, records) == len(records)
    assert seed_resources(db_session, records) == 0

    first = db_session.scalar(select(Resource).where(Resource.name == records[0].name))
    second = db_session.scalar(select(Resource).where(Resource.name == records[1].name))
    first.is_active = False
    second.last_verified_at = datetime.now(UTC) - timedelta(days=181)
    db_session.flush()
    assert seed_resources(db_session, records) == 0

    listed = list_resources(db_session, ResourceQuery(area="Oklahoma City Metro"))
    assert len(listed) == len(records) - 2
    assert {first.id, second.id}.isdisjoint({resource.id for resource in listed})
    assert db_session.scalar(select(func.count()).select_from(Resource)) == len(records)


def test_duplicate_source_in_manifest_is_rejected(tmp_path):
    import json

    from scripts.seed_resources import SEED_PATH, load_seed

    data = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    path = tmp_path / "duplicate.json"
    path.write_text(json.dumps([data[0], data[0]]), encoding="utf-8")
    with pytest.raises(ValueError, match="Duplicate source URL"):
        load_seed(path)
