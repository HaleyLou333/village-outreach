"""Sprint 4 resource discovery and private report integration checks."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from tests.test_request_api import headers, payload
from tests.test_request_api import request_client as request_client

pytestmark = pytest.mark.database


def test_resources_require_authentication(request_client):
    assert request_client.get("/resources").status_code == 401
    assert request_client.get(f"/resources/{uuid4()}").status_code == 401


def test_resource_visibility_and_filters(request_client, db_session, claims, signing_key):
    from app.models import Resource

    current = datetime.now(UTC)
    common = {
        "category": "food",
        "area": "Oklahoma City",
        "address": "1 Synthetic St",
        "latitude": 35.47,
        "longitude": -97.52,
        "source_url": "https://example.invalid/provider",
        "last_verified_at": current - timedelta(days=1),
    }
    rows = [
        Resource(name="A current", **common),
        Resource(name="B current", **common),
        Resource(name="C disabled", **(common | {"is_active": False})),
        Resource(name="D stale", **(common | {"last_verified_at": current - timedelta(days=181)})),
        Resource(name="E other", **(common | {"area": "Edmond", "latitude": 35.66})),
        Resource(name="F category", **(common | {"category": "library"})),
    ]
    db_session.add_all(rows)
    db_session.flush()
    ids = [str(row.id) for row in rows]
    auth = headers(claims, signing_key)
    route = "/resources?area=oklahoma%20city&category=food"
    page = request_client.get(route, headers=auth)
    assert page.status_code == 200
    assert [item["id"] for item in page.json()] == ids[:2]
    assert [
        item["id"] for item in request_client.get(route + "&limit=1&offset=1", headers=auth).json()
    ] == ids[1:2]
    assert request_client.get("/resources?area=Unknown", headers=auth).json() == []
    near = request_client.get(
        "/resources?category=food&latitude=35.47&longitude=-97.52&radius_km=5",
        headers=auth,
    )
    assert [item["id"] for item in near.json()] == ids[:2]
    detail = request_client.get(f"/resources/{ids[0]}", headers=auth).json()
    assert detail["source_url"] == common["source_url"]
    assert detail["latitude"] == 35.47
    assert datetime.fromisoformat(detail["last_verified_at"]) == common["last_verified_at"]
    assert "organization_id" not in detail
    for hidden in ids[2:4]:
        assert request_client.get(f"/resources/{hidden}", headers=auth).status_code == 404


@pytest.mark.parametrize(
    "query",
    [
        "latitude=35",
        "radius_km=10",
        "latitude=NaN&longitude=0",
        "area=%20",
        "category=food%20bank",
        "limit=101",
        "offset=-1",
    ],
)
def test_invalid_resource_filters(request_client, claims, signing_key, query):
    assert (
        request_client.get(f"/resources?{query}", headers=headers(claims, signing_key)).status_code
        == 422
    )


def test_report_submission_privacy_and_retry(request_client, db_session, claims, signing_key):
    owner = headers(claims | {"sub": str(uuid4())}, signing_key)
    reporter = headers(claims, signing_key, key="report-key-001")
    owner_id = request_client.get("/users/me", headers=owner).json()["id"]
    reporter_id = request_client.get("/users/me", headers=reporter).json()["id"]
    request = request_client.post("/requests", headers=owner, json=payload()).json()
    data = {
        "target_type": "request",
        "target_id": request["id"],
        "reason": "spam",
        "description": "  Repeated promotion  ",
    }
    assert request_client.post("/reports", json=data).status_code == 401
    submitted = request_client.post("/reports", headers=reporter, json=data)
    assert submitted.status_code == 201
    assert set(submitted.json()) == {"id", "status"}
    assert submitted.json()["status"] == "pending"
    replay = request_client.post("/reports", headers=reporter, json=data)
    assert replay.status_code == 200
    assert replay.json() == submitted.json()
    assert (
        request_client.post(
            "/reports", headers=reporter, json=data | {"reason": "other"}
        ).status_code
        == 409
    )
    assert request_client.get("/reports", headers=reporter).status_code == 405
    assert (
        request_client.get(f"/reports/{submitted.json()['id']}", headers=owner).status_code == 404
    )

    reporter = reporter | {"Idempotency-Key": "report-key-002"}
    account_report = data | {"target_type": "user", "target_id": owner_id}
    for invalid in (
        account_report | {"target_id": str(uuid4())},
        data | {"target_id": str(uuid4())},
    ):
        assert request_client.post("/reports", headers=reporter, json=invalid).status_code == 404
    for invalid in (
        account_report | {"target_type": "offer"},
        account_report | {"reason": "unknown"},
        account_report | {"reporter_id": owner_id},
        account_report | {"description": "\x00"},
    ):
        assert request_client.post("/reports", headers=reporter, json=invalid).status_code == 422
    assert (
        request_client.post(
            "/reports", headers=reporter, json=account_report | {"target_id": reporter_id}
        ).status_code
        == 403
    )
    assert request_client.post("/reports", headers=reporter, json=account_report).status_code == 201

    from app.models import Report

    saved = db_session.scalars(select(Report).order_by(Report.created_at)).all()
    assert len(saved) == 2
    assert saved[0].description == "Repeated promotion"
    assert str(saved[0].reporter_id) == reporter_id
    assert str(saved[0].request_id) == request["id"]
    assert str(saved[1].reported_user_id) == owner_id
    assert db_session.scalar(select(func.count()).select_from(Report)) == 2
