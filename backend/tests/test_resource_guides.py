"""Published guide API checks against disposable PostgreSQL."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest

from app.models import ResourceGuide
from tests.test_request_api import headers
from tests.test_request_api import request_client as request_client

pytestmark = pytest.mark.database


def test_only_published_guides_are_visible(request_client, db_session, claims, signing_key):
    reviewed = datetime(2026, 11, 15, 12, tzinfo=UTC)
    fields = {
        "title": "Local food assistance",
        "body": "Contact the listed intake office before visiting.",
        "category": "food",
        "area": "Midtown",
        "source_url": "https://example.org/intake",
        "reviewed_at": reviewed,
        "published": True,
    }
    guides = [
        ResourceGuide(**(fields | changes))
        for changes in [
            {},
            {"reviewed_at": reviewed - timedelta(days=1)},
            {"category": "housing"},
            {"area": "Downtown"},
            {"published": False, "reviewed_at": None},
        ]
    ]
    db_session.add_all(guides)
    db_session.flush()
    ids = [str(guide.id) for guide in guides]
    db_session.commit()

    path = "/resource-guides"
    auth = headers(claims, signing_key)
    assert request_client.get(path).status_code == 401
    assert {row["id"] for row in request_client.get(path, headers=auth).json()} == set(ids[:4])
    filters = {"category": "food", "area": " midtown ", "limit": 1}
    for offset, expected in enumerate([[ids[0]], [ids[1]], []]):
        page = request_client.get(path, headers=auth, params=filters | {"offset": offset})
        assert page.status_code == 200
        assert [row["id"] for row in page.json()] == expected
        assert all("body" not in row for row in page.json())
    assert request_client.get(path, headers=auth, params={"category": "BAD!"}).status_code == 422

    detail = request_client.get(f"{path}/{ids[0]}", headers=auth)
    assert detail.status_code == 200
    assert detail.json()["source_url"] == fields["source_url"]
    assert detail.json()["body"] == fields["body"]
    assert datetime.fromisoformat(detail.json()["reviewed_at"]) == reviewed
    for identifier in [ids[4], uuid4()]:
        assert request_client.get(f"{path}/{identifier}", headers=auth).status_code == 404
    assert request_client.post(path, headers=auth, json={}).status_code == 405
    assert request_client.patch(f"{path}/{ids[0]}", headers=auth, json={}).status_code == 405
