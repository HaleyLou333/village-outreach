"""Request API integration checks against disposable PostgreSQL."""

import json
import math
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.auth import dependencies
from app.database.session import get_session
from app.main import app
from app.models import HelpRequest
from tests.auth_helpers import encode

pytestmark = pytest.mark.database


@pytest.fixture
def request_client(db_session, verifier, monkeypatch):
    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_session] = lambda: db_session
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)


def payload(**changes):
    return (
        dict(
            title=" Groceries ",
            description=" Need food ",
            category="FOOD_ASSISTANCE",
            urgency="standard",
            latitude=35.4676,
            longitude=-97.5164,
            area=" Midtown ",
        )
        | changes
    )


def headers(claims, signing_key, key="request-key-001"):
    return {"Authorization": "Bearer " + encode(claims, signing_key), "Idempotency-Key": key}


def create(client, claims, signing_key, **changes):
    return client.post("/requests", headers=headers(claims, signing_key), json=payload(**changes))


def test_create_reloads_normalizes_and_limits_public_data(
    request_client, db_session, claims, signing_key
):
    response = create(request_client, claims, signing_key)
    assert response.status_code == 201
    body = response.json()
    assert set(body) == {
        "id",
        "requester_id",
        "title",
        "description",
        "category",
        "urgency",
        "latitude",
        "longitude",
        "area",
        "status",
        "created_at",
        "updated_at",
    }
    assert body["title"] == "Groceries"
    assert body["latitude"] == 35.47
    assert body["longitude"] == -97.52
    assert body["status"] == "active"
    db_session.expunge_all()
    detail = request_client.get("/requests/" + body["id"], headers=headers(claims, signing_key))
    assert detail.json() == body
    assert db_session.scalar(select(func.count()).select_from(HelpRequest)) == 1


def test_idempotency_replay_uses_original_payload_after_edit(request_client, claims, signing_key):
    first = create(request_client, claims, signing_key)
    route = "/requests/" + first.json()["id"]
    auth = headers(claims, signing_key)
    edit = request_client.patch(route, headers=auth, json={"title": "New title"})
    assert edit.status_code == 200
    replay = create(request_client, claims, signing_key, title="Groceries")
    assert replay.status_code == 200
    assert replay.json() == edit.json()
    conflict = create(request_client, claims, signing_key, title="Different")
    assert conflict.status_code == 409


def test_owner_closing_and_closed_retry_rules(request_client, claims, signing_key):
    first = create(request_client, claims, signing_key).json()
    route = "/requests/" + first["id"]
    auth = headers(claims, signing_key)
    other = headers(claims | {"sub": str(uuid4()), "email": "other@example.com"}, signing_key)
    assert request_client.patch(route, headers=other, json={"title": "Stolen"}).status_code == 403
    closed = request_client.patch(route, headers=auth, json={"status": "completed"})
    assert closed.status_code == 200
    assert (
        request_client.patch(route, headers=auth, json={"status": "completed"}).json()
        == closed.json()
    )
    for body in [
        {"title": "Edit"},
        {"status": "active"},
        {"status": "canceled"},
        {"status": "completed", "title": "Edit"},
    ]:
        assert request_client.patch(route, headers=auth, json=body).status_code == 409
    assert request_client.get(route, headers=other).status_code == 200
    feed = request_client.get(
        "/requests", headers=auth, params={"latitude": 35.46, "longitude": -97.51}
    )
    assert feed.json() == []


def test_idempotency_key_is_scoped_to_requester(request_client, claims, signing_key):
    first = create(request_client, claims, signing_key)
    second = create(
        request_client, claims | {"sub": str(uuid4()), "email": "other@example.com"}, signing_key
    )
    assert first.status_code == second.status_code == 201
    assert first.json()["id"] != second.json()["id"]


@pytest.mark.parametrize(
    "change",
    [
        {"title": " "},
        {"status": "active"},
        {"id": str(uuid4())},
        {"requester_id": str(uuid4())},
        {"creation_hash": "x"},
        {"idempotency_key": "x"},
        {"latitude": 91},
        {"longitude": 181},
        {"title": "bad\x00"},
        {"title": "\ud800"},
    ],
)
def test_invalid_create_is_atomic(request_client, db_session, claims, signing_key, change):
    response = request_client.post(
        "/requests", headers=headers(claims, signing_key), content=json.dumps(payload(**change))
    )
    assert response.status_code == 422
    assert db_session.scalar(select(func.count()).select_from(HelpRequest)) == 0


@pytest.mark.parametrize("key", [None, "short", "contains spaces", "nonascii-é", "x" * 129])
def test_key_validation(request_client, claims, signing_key, key):
    auth = headers(claims, signing_key)
    if key is None:
        auth.pop("Idempotency-Key")
    else:
        auth["Idempotency-Key"] = key
    # httpx headers are ASCII, so send non-ASCII as bytes.
    if key == "nonascii-é":
        auth["Idempotency-Key"] = key.encode("utf-8")
    assert request_client.post("/requests", headers=auth, json=payload()).status_code == 422


@pytest.mark.parametrize(
    "body",
    [
        {},
        {"latitude": 0},
        {"longitude": 0},
        {"title": None},
        {"updated_at": "2026-01-01"},
        {"unknown": "x"},
    ],
)
def test_invalid_patch_does_not_change_row(request_client, claims, signing_key, body):
    original = create(request_client, claims, signing_key).json()
    route = "/requests/" + original["id"]
    auth = headers(claims, signing_key)
    assert request_client.patch(route, headers=auth, json=body).status_code == 422
    assert request_client.get(route, headers=auth).json() == original


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"latitude": 0},
        {"latitude": 91, "longitude": 0},
        {"latitude": "nan", "longitude": 0},
        {"latitude": 0, "longitude": "inf"},
        {"latitude": 0, "longitude": 0, "radius_km": 0},
        {"latitude": 0, "longitude": 0, "radius_km": 101},
        {"latitude": 0, "longitude": 0, "limit": 101},
        {"latitude": 0, "longitude": 0, "offset": 10001},
    ],
)
def test_invalid_feed_query(request_client, claims, signing_key, params):
    assert (
        request_client.get(
            "/requests", headers=headers(claims, signing_key), params=params
        ).status_code
        == 422
    )


@pytest.mark.parametrize(
    "method,path,body",
    [
        ("post", "/requests", payload()),
        ("get", "/requests?latitude=0&longitude=0", None),
        ("get", "/requests/" + str(uuid4()), None),
        ("patch", "/requests/" + str(uuid4()), {"title": "Edit"}),
    ],
)
def test_routes_require_authentication(request_client, method, path, body):
    options = {"json": body} if body is not None else {}
    assert request_client.request(method, path, **options).status_code == 401


def test_missing_and_malformed_ids(request_client, claims, signing_key):
    for method in ["get", "patch"]:
        options = {"json": {"title": "Edit"}} if method == "patch" else {}
        for identifier, status in [(str(uuid4()), 404), ("invalid", 422)]:
            assert (
                request_client.request(
                    method,
                    "/requests/" + identifier,
                    headers=headers(claims, signing_key),
                    **options,
                ).status_code
                == status
            )


@pytest.mark.parametrize(
    "center,near,far,public_near,public_far",
    [
        ((0, 179.99), (0, -179.994), (0, -178), (0, -179.99), (0, -178)),
        ((89.99, 0), (89.994, 180), (88.004, 0), (89.99, 180), (88, 0)),
        ((0, 0), (0, 0.0849), (0, 0.085), (0, 0.08), (0, 0.09)),
    ],
)
def test_distance_filter_handles_boundaries_dateline_poles(
    request_client, claims, signing_key, center, near, far, public_near, public_far
):
    expected_distances = {}
    for index, (point, public_point) in enumerate(
        zip([near, far], [public_near, public_far], strict=True)
    ):
        response = request_client.post(
            "/requests",
            headers=headers(claims, signing_key, f"location-key-{index}"),
            json=payload(latitude=point[0], longitude=point[1]),
        )
        assert response.status_code == 201
        assert (response.json()["latitude"], response.json()["longitude"]) == public_point
        # Independent Python spherical distance on the explicitly expected cell,
        # rather than reproducing the SQL expression or consulting raw storage.
        lat1, lon1 = map(math.radians, center)
        lat2, lon2 = map(math.radians, public_point)
        haversine = math.sin((lat2 - lat1) / 2) ** 2 + (
            math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
        )
        expected_distances[response.json()["id"]] = (
            6371.0088 * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine))
        )
    feed = request_client.get(
        "/requests",
        headers=headers(claims, signing_key),
        params={"latitude": center[0], "longitude": center[1], "radius_km": 10},
    ).json()
    assert {row["id"] for row in feed} == {
        key for key, distance in expected_distances.items() if distance <= 10
    }
    for row in feed:
        assert row["distance_km"] == round(expected_distances[row["id"]], 1)
    for request_id, distance in expected_distances.items():
        if 0.000001 < distance < 99:
            for epsilon, included in [(-0.000001, False), (0.000001, True)]:
                boundary = request_client.get(
                    "/requests",
                    headers=headers(claims, signing_key),
                    params={
                        "latitude": center[0],
                        "longitude": center[1],
                        "radius_km": distance + epsilon,
                    },
                )
                assert boundary.status_code == 200
                assert (request_id in {row["id"] for row in boundary.json()}) == included


def test_feed_pagination_is_deterministic(request_client, claims, signing_key):
    for index in range(3):
        assert (
            request_client.post(
                "/requests",
                headers=headers(claims, signing_key, f"pagination-{index}"),
                json=payload(title=f"Request {index}"),
            ).status_code
            == 201
        )
    query = {"latitude": 35.4676, "longitude": -97.5164, "limit": 1}
    pages = [
        request_client.get(
            "/requests", headers=headers(claims, signing_key), params=query | {"offset": index}
        ).json()
        for index in range(3)
    ]
    assert len({page[0]["id"] for page in pages}) == 3
    assert (
        request_client.get("/requests", headers=headers(claims, signing_key), params=query).json()
        == pages[0]
    )


@pytest.mark.parametrize("different_payload", [False, True])
def test_concurrent_retries_are_arbitrated_by_database(
    db_engine, verifier, monkeypatch, claims, signing_key, different_payload
):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier
    from uuid import UUID

    from sqlalchemy import delete, event
    from sqlalchemy.orm import Session

    from app.models import User

    owner_id = uuid4()
    subject = UUID(claims["sub"])
    with Session(db_engine) as session:
        session.add(
            User(
                id=owner_id,
                supabase_uid=subject,
                email="concurrent@example.com",
                display_name="Concurrent",
            )
        )
        session.commit()

    def independent_session():
        with Session(db_engine) as session:
            yield session

    # Both requests reach their actual INSERT before either proceeds. Separate
    # committed transactions exercise PostgreSQL's unique-key wait/recheck path.
    at_insert = Barrier(2)

    def synchronize_inserts(_connection, _cursor, statement, _parameters, _context, _many):
        if statement.startswith("INSERT INTO app_private.help_requests"):
            at_insert.wait(timeout=10)

    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_session] = independent_session
    event.listen(db_engine, "before_cursor_execute", synchronize_inserts)
    try:

        def send(index):
            with TestClient(app) as client:
                return create(
                    client,
                    claims,
                    signing_key,
                    title="Different" if different_payload and index else "Groceries",
                )

        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(send, [0, 1]))
        assert sorted(response.status_code for response in responses) == (
            [201, 409] if different_payload else [200, 201]
        )
        if not different_payload:
            assert responses[0].json() == responses[1].json()
        with Session(db_engine) as session:
            assert (
                session.scalar(
                    select(func.count())
                    .select_from(HelpRequest)
                    .where(HelpRequest.requester_id == owner_id)
                )
                == 1
            )
    finally:
        event.remove(db_engine, "before_cursor_execute", synchronize_inserts)
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)
        with Session(db_engine) as session:
            session.execute(delete(HelpRequest).where(HelpRequest.requester_id == owner_id))
            session.execute(delete(User).where(User.id == owner_id, User.supabase_uid == subject))
            session.commit()


def test_failed_create_commit_rolls_back_without_leaking_database_error(
    request_client, db_session, claims, signing_key, monkeypatch
):
    from sqlalchemy.exc import OperationalError

    auth = headers(claims, signing_key)
    assert request_client.get("/users/me", headers=auth).status_code == 200

    def fail_commit():
        raise OperationalError("commit", {}, RuntimeError("private-database-error"))

    with monkeypatch.context() as patch:
        patch.setattr(db_session, "commit", fail_commit)
        response = create(request_client, claims, signing_key)
    assert response.status_code == 503
    assert "private-database-error" not in response.text
    assert db_session.scalar(select(func.count()).select_from(HelpRequest)) == 0
    assert create(request_client, claims, signing_key).status_code == 201


def test_failed_update_commit_preserves_original_request(
    request_client, db_session, claims, signing_key, monkeypatch
):
    from sqlalchemy.exc import OperationalError

    original = create(request_client, claims, signing_key).json()
    route = "/requests/" + original["id"]

    def fail_commit():
        raise OperationalError("commit", {}, RuntimeError("private-database-error"))

    with monkeypatch.context() as patch:
        patch.setattr(db_session, "commit", fail_commit)
        response = request_client.patch(
            route,
            headers=headers(claims, signing_key),
            json={"status": "completed", "title": "Changed"},
        )
    assert response.status_code == 503
    assert request_client.get(route, headers=headers(claims, signing_key)).json() == original


@pytest.mark.parametrize(
    "center,radius_km",
    [
        ((35.4676, -97.5164), 0.000001),
        ((35.4690, -97.5164), 0.000001),
        ((35.47, -97.52), 0.000001),
        ((35.4676, -97.5164), 0.1),
        ((35.4676, -97.5164), 0.3),
        ((35.46, -97.51), 1),
        ((35.50, -97.50), 10),
    ],
)
def test_same_public_cell_cannot_be_distinguished_by_radius_or_distance(
    request_client, claims, signing_key, center, radius_km
):
    ids = []
    for index, latitude in enumerate([35.4676, 35.4690]):
        response = request_client.post(
            "/requests",
            headers=headers(claims, signing_key, f"privacy-cell-{index}"),
            json=payload(latitude=latitude, longitude=-97.5164),
        )
        assert response.status_code == 201
        ids.append(response.json()["id"])
    response = request_client.get(
        "/requests",
        headers=headers(claims, signing_key),
        params={"latitude": center[0], "longitude": center[1], "radius_km": radius_km},
    )
    assert response.status_code == 200
    feed = response.json()
    assert len(feed) in (0, 2)
    if feed:
        assert {row["id"] for row in feed} == set(ids)
        assert len({row["distance_km"] for row in feed}) == 1
        assert [row["id"] for row in feed] == sorted(ids)


@pytest.mark.parametrize(
    "point,public_point",
    [
        ((35.125, -97.125), (35.13, -97.13)),
        ((-35.125, 97.125), (-35.13, 97.13)),
        ((35.12499999999999, -97.12499999999999), (35.12, -97.12)),
        ((35.12500000000001, -97.12500000000001), (35.13, -97.13)),
    ],
)
def test_public_rounding_and_sql_filter_match_at_and_near_half_ties(
    request_client, claims, signing_key, point, public_point
):
    response = create(request_client, claims, signing_key, latitude=point[0], longitude=point[1])
    assert response.status_code == 201
    assert (response.json()["latitude"], response.json()["longitude"]) == public_point
    feed = request_client.get(
        "/requests",
        headers=headers(claims, signing_key),
        params={"latitude": public_point[0], "longitude": public_point[1], "radius_km": 0.000001},
    )
    assert feed.status_code == 200
    assert len(feed.json()) == 1
    assert feed.json()[0]["distance_km"] == 0
