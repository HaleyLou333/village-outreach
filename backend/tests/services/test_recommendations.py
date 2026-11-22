"""Verified resource recommendation tests."""

from datetime import UTC, datetime, timedelta

import pytest

from app.models import Resource
from app.schemas.resources import ResourceQuery
from app.services.recommendations import recommend_resources
from app.services.resources import RESOURCE_VERIFICATION_MAX_AGE

pytestmark = pytest.mark.database


def test_recommend_resources_returns_empty_when_no_matches(
        db_session,
):
    results = recommend_resources(
        db_session,
        ResourceQuery(
            category="food_assistance",
        ),
    )

    assert results == []


def test_recommend_resources_excludes_stale_resources(
        db_session,
):
    stale_resource = Resource(
        name="Old Food Pantry",
        category="food_assistance",
        area="oklahoma_city",
        address="123 Main St",
        latitude=35.4676,
        longitude=-97.5164,
        phone="555-1111",
        website="https://example.org",
        source_url="https://source.example.org",
        is_active=True,
        last_verified_at=(
                datetime.now(UTC)
                - RESOURCE_VERIFICATION_MAX_AGE
                - timedelta(days=1)
        ),
    )

    db_session.add(stale_resource)
    db_session.commit()

    results = recommend_resources(
        db_session,
        ResourceQuery(
            category="food_assistance",
        ),
    )

    assert results == []


def test_recommend_resources_excludes_wrong_area(
        db_session,
):
    resource = Resource(
        name="Food Pantry",
        category="food_assistance",
        area="tulsa",
        address="123 Main St",
        latitude=35.4676,
        longitude=-97.5164,
        phone="555-1111",
        website="https://example.org",
        source_url="https://source.example.org",
        is_active=True,
        last_verified_at=datetime.now(UTC),
    )

    db_session.add(resource)
    db_session.commit()

    results = recommend_resources(
        db_session,
        ResourceQuery(
            category="food_assistance",
            area="oklahoma_city",
        ),
    )

    assert results == []


def test_recommend_resources_orders_by_distance(
        db_session,
):
    near_resource = Resource(
        name="Near Pantry",
        category="food_assistance",
        area="oklahoma_city",
        address="123 Near St",
        latitude=35.4676,
        longitude=-97.5164,
        phone="555-1111",
        website="https://example.org",
        source_url="https://source.example.org",
        is_active=True,
        last_verified_at=datetime.now(UTC),
    )

    far_resource = Resource(
        name="Far Pantry",
        category="food_assistance",
        area="oklahoma_city",
        address="456 Far St",
        latitude=35.7000,
        longitude=-97.8000,
        phone="555-2222",
        website="https://example.org",
        source_url="https://source.example.org",
        is_active=True,
        last_verified_at=datetime.now(UTC),
    )

    db_session.add_all(
        [
            near_resource,
            far_resource,
        ]
    )
    db_session.commit()

    results = recommend_resources(
        db_session,
        ResourceQuery(
            category="food_assistance",
            latitude=35.4676,
            longitude=-97.5164,
            radius_km=100,
        ),
    )

    assert len(results) == 2
    assert results[0].name == "Near Pantry"
    assert results[1].name == "Far Pantry"