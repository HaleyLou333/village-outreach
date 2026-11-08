"""Sprint 3 authorization, persistence, retry and closure contracts."""

import json
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError

from app.models import Message, Offer
from tests.test_request_api import headers, payload
from tests.test_request_api import request_client as request_client

pytestmark = pytest.mark.database


@pytest.fixture
def journey(request_client, claims, signing_key):
    auth = [
        headers(claims | {"sub": str(uuid4()), "email": f"p{i}@example.com"}, signing_key)
        for i in range(4)
    ]
    users = [request_client.get("/users/me", headers=h).json()["id"] for h in auth]
    request = request_client.post("/requests", headers=auth[0], json=payload()).json()
    return request_client, auth, users, request["id"]


def offer(client, auth, request_id, message="I can help", key="offer-key-001"):
    return client.post(
        "/offers",
        headers=auth | {"Idempotency-Key": key, "Content-Type": "application/json"},
        content=json.dumps({"request_id": request_id, "message": message}),
    )


def accept(client, auth, offer_id):
    return client.post(f"/offers/{offer_id}/accept", headers=auth)


def test_offer_creation_retry_and_validation(journey):
    client, auth, users, rid = journey
    first = offer(client, auth[1], rid, "  I can help  ")
    assert first.status_code == 201
    assert first.json()["helper_id"] == users[1]
    assert first.json()["message"] == "I can help"
    assert first.json()["status"] == "pending"
    assert offer(client, auth[1], rid).status_code == 200
    assert offer(client, auth[1], rid, "Different").status_code == 409
    assert offer(client, auth[1], rid, key="another-key-001").status_code == 409
    assert offer(client, auth[0], rid).status_code == 403
    assert offer(client, auth[2], str(uuid4())).status_code == 404
    assert offer(client, {}, rid).status_code == 401
    for value in ["", " ", "x" * 4001, None, 4, "\x00", "\ud800"]:
        assert offer(client, auth[2], rid, value).status_code == 422
    assert (
        client.post(
            "/offers",
            headers=auth[2],
            json={"request_id": rid, "message": "help", "helper_id": users[0]},
        ).status_code
        == 422
    )


def test_offer_visibility_acceptance_and_stale_actions(journey):
    client, auth, users, rid = journey
    first = offer(client, auth[1], rid).json()
    second = offer(client, auth[2], rid).json()
    route = f"/requests/{rid}/offers"
    assert len(client.get(route, headers=auth[0]).json()) == 2
    assert [o["id"] for o in client.get(route, headers=auth[1]).json()] == [first["id"]]
    assert client.get(route, headers=auth[3]).json() == []
    assert accept(client, auth[1], first["id"]).status_code == 403
    result = accept(client, auth[0], first["id"])
    assert result.status_code == 200
    assert result.json()["status"] == "accepted"
    assert accept(client, auth[0], first["id"]).json() == result.json()
    assert accept(client, auth[0], second["id"]).status_code == 409
    states = {o["id"]: o["status"] for o in client.get(route, headers=auth[0]).json()}
    assert states == {first["id"]: "accepted", second["id"]: "declined"}
    assert offer(client, auth[3], rid).status_code == 409
    assert client.get(route + "?limit=0", headers=auth[0]).status_code == 422
    assert len(client.get(route + "?limit=1&offset=1", headers=auth[0]).json()) == 1


@pytest.mark.parametrize("status", ["completed", "canceled"])
def test_closed_requests_reject_new_offers_and_acceptance(journey, status):
    client, auth, users, rid = journey
    first = offer(client, auth[1], rid).json()
    assert (
        client.patch(f"/requests/{rid}", headers=auth[0], json={"status": status}).status_code
        == 200
    )
    assert accept(client, auth[0], first["id"]).status_code == 409
    assert offer(client, auth[2], rid).status_code == 409
    assert offer(client, auth[1], rid).status_code == 200


def send(client, auth, rid, receiver, body="Hello", key="message-key-001"):
    return client.post(
        "/messages",
        headers=auth | {"Idempotency-Key": key, "Content-Type": "application/json"},
        content=json.dumps({"request_id": rid, "receiver_id": receiver, "body": body}),
    )


@pytest.mark.parametrize("status", ["completed", "canceled"])
def test_private_messages_retries_and_closed_history(journey, status):
    client, auth, users, rid = journey
    route = f"/requests/{rid}/messages"
    assert client.get(route, headers=auth[0]).status_code == 403
    first = offer(client, auth[1], rid).json()
    offer(client, auth[2], rid)
    assert accept(client, auth[0], first["id"]).status_code == 200
    message = send(client, auth[0], rid, users[1], "  Hello  ")
    assert message.status_code == 201
    assert message.json()["sender_id"] == users[0]
    assert message.json()["body"] == "Hello"
    assert send(client, auth[0], rid, users[1]).status_code == 200
    assert send(client, auth[0], rid, users[1], "Changed").status_code == 409
    assert send(client, auth[1], rid, users[0], "Reply").status_code == 201
    for index in [2, 3]:
        assert client.get(route, headers=auth[index]).status_code == 403
        assert send(client, auth[index], rid, users[0]).status_code == 403
    assert send(client, auth[0], rid, users[2], key="wrong-user-001").status_code == 403
    assert send(client, auth[0], rid, users[0], key="self-user-001").status_code == 403
    history = client.get(route, headers=auth[1])
    assert history.status_code == 200 and len(history.json()) == 2
    assert history.headers["Cache-Control"] == "no-store"
    assert message.headers["Cache-Control"] == "no-store"
    assert client.get(route + "?limit=1&offset=1", headers=auth[0]).json() == history.json()[1:]
    assert client.get(route + "?limit=101", headers=auth[0]).status_code == 422
    assert (
        client.patch(f"/requests/{rid}", headers=auth[0], json={"status": status}).status_code
        == 200
    )
    assert client.get(route, headers=auth[0]).json() == history.json()
    assert client.get(route, headers=auth[1]).json() == history.json()
    assert send(client, auth[0], rid, users[1], key="new-message-001").status_code == 409
    assert send(client, auth[0], rid, users[1]).status_code == 200
    assert client.get(route, headers=auth[3]).status_code == 403


def test_message_input_authentication_and_unknown_request(journey):
    client, auth, users, rid = journey
    first = offer(client, auth[1], rid).json()
    accept(client, auth[0], first["id"])
    for value in ["", " ", "x" * 4001, None, 4, "\x00", "\ud800"]:
        assert send(client, auth[0], rid, users[1], value).status_code == 422
    assert send(client, {}, rid, users[1]).status_code == 401
    assert send(client, auth[0], str(uuid4()), users[1]).status_code == 404
    assert (
        client.post(
            "/messages",
            headers=auth[0],
            json={"request_id": rid, "receiver_id": users[1], "body": "Hi", "sender_id": users[2]},
        ).status_code
        == 422
    )


def test_acceptance_failure_rolls_back_all_offer_states(journey, db_session, monkeypatch):
    client, auth, users, rid = journey
    first = offer(client, auth[1], rid).json()
    offer(client, auth[2], rid)

    def failed_commit():
        raise SQLAlchemyError("private storage diagnostic")

    monkeypatch.setattr(db_session, "commit", failed_commit)
    response = accept(client, auth[0], first["id"])
    assert response.status_code == 503
    assert "private storage diagnostic" not in response.text
    assert list(db_session.scalars(select(Offer.status).where(Offer.request_id == rid))) == [
        "pending",
        "pending",
    ]


@pytest.mark.parametrize("kind", ["offer", "message"])
def test_failed_creation_rolls_back_insert(journey, db_session, monkeypatch, kind):
    client, auth, users, rid = journey
    if kind == "message":
        first = offer(client, auth[1], rid).json()
        accept(client, auth[0], first["id"])

    def failed_commit():
        raise SQLAlchemyError("private storage diagnostic")

    monkeypatch.setattr(db_session, "commit", failed_commit)
    if kind == "offer":
        response = offer(client, auth[2], rid)
        rows = db_session.scalars(select(Offer).where(Offer.helper_id == users[2])).all()
    else:
        response = send(client, auth[0], rid, users[1])
        rows = db_session.scalars(select(Message).where(Message.request_id == rid)).all()
    assert response.status_code == 503 and rows == []
    assert "private storage diagnostic" not in response.text
