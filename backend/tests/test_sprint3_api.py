"""Sprint 3 authorization, persistence, retry and closure contracts."""

import json
from base64 import b64decode, b64encode
from io import BytesIO
from uuid import UUID, uuid4

import pytest
from PIL import Image
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError

from app.models import HelpRequest, Message, Offer
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


def test_member_cards_scope_photo_access_to_offers_and_accepted_chat(journey):
    client, auth, users, rid = journey
    owner, helper, outsider, _ = auth
    helper_card = f"/requests/{rid}/members/{users[1]}"
    owner_card = f"/requests/{rid}/members/{users[0]}"
    photo_path = "/users/me/shared-photo"

    original = BytesIO()
    image = Image.new("RGB", (12, 12))
    exif = Image.Exif()
    exif[270] = "Private description"
    image.save(original, "JPEG", exif=exif)
    assert client.put(photo_path, headers=helper, json={"photo": "AAAA"}).status_code == 422
    shared = client.put(
        photo_path, headers=helper, json={"photo": b64encode(original.getvalue()).decode("ascii")}
    )
    assert shared.status_code == 200
    assert client.get(photo_path, headers=helper).json() == shared.json()
    assert client.get(photo_path, headers=outsider).json() == {"photo": None}
    assert client.get(helper_card, headers=owner).status_code == 404

    created = offer(client, helper, rid)
    assert created.status_code == 201
    assert client.get(helper_card).status_code == 401
    assert client.get(helper_card, headers=outsider).status_code == 404
    assert client.get(owner_card, headers=helper).status_code == 404
    card = client.get(helper_card, headers=owner)
    assert card.status_code == 200
    assert card.headers["Cache-Control"] == "no-store"
    assert set(card.json()) == {"display_name", "completed_help_count", "badges", "photo"}
    offers = client.get(f"/requests/{rid}/offers", headers=owner).json()
    assert offers[0]["helper_display_name"] == card.json()["display_name"]
    with Image.open(BytesIO(b64decode(card.json()["photo"]))) as displayed:
        assert displayed.format == "JPEG"
        assert not displayed.getexif()

    assert accept(client, owner, created.json()["id"]).status_code == 200
    assert client.get(owner_card, headers=helper).status_code == 200
    assert client.get(owner_card, headers=outsider).status_code == 404
    assert (
        client.patch(f"/requests/{rid}", headers=owner, json={"status": "completed"}).status_code
        == 200
    )
    progress = client.get(helper_card, headers=owner).json()
    assert progress["completed_help_count"] == 1
    assert progress["badges"] == ["First Help"]
    assert client.delete(photo_path, headers=helper).status_code == 204
    assert client.get(helper_card, headers=owner).json()["photo"] is None


def test_notifications_are_private_and_idempotent(journey, db_session):
    client, auth, users, rid = journey
    path = "/notifications"
    assert client.get(path).status_code == 401
    first = offer(client, auth[1], rid)
    assert first.status_code == 201
    assert offer(client, auth[1], rid).status_code == 200
    for _ in range(2):
        assert accept(client, auth[0], first.json()["id"]).status_code == 200
    assert send(client, auth[1], rid, users[0]).status_code == 201
    assert send(client, auth[1], rid, users[0]).status_code == 200

    inbox = client.get(path, headers=auth[0])
    assert inbox.status_code == 200
    assert inbox.headers["Cache-Control"] == "no-store"
    newest, oldest = inbox.json()
    assert [newest["type"], oldest["type"]] == ["message_received", "offer_received"]
    for event in [newest, oldest]:
        assert set(event) == {"id", "type", "request_id", "created_at", "read_at"}
        assert event["request_id"] == rid and event["read_at"] is None
    assert [event["type"] for event in client.get(path, headers=auth[1]).json()] == [
        "offer_accepted"
    ]
    assert client.get(path, headers=auth[2]).json() == []

    read_path = f"{path}/{newest['id']}/read"
    assert client.patch(read_path, headers=auth[1]).status_code == 404
    assert client.patch(read_path).status_code == 401
    marked = client.patch(read_path, headers=auth[0])
    assert marked.status_code == 200
    assert marked.json()["read_at"] is not None
    db_session.expunge_all()
    assert client.patch(read_path, headers=auth[0]).json() == marked.json()
    assert client.get(path, headers=auth[0]).json() == [oldest, marked.json()]


def test_removing_request_clears_linked_notification(journey, db_session):
    from app.models import Notification

    client, auth, users, rid = journey
    request = db_session.get(HelpRequest, UUID(rid))
    notification = Notification(
        recipient_id=UUID(users[0]), request_id=request.id, type="offer_received"
    )
    db_session.add(notification)
    db_session.flush()
    notification_id = notification.id
    db_session.delete(request)
    db_session.commit()
    assert client.get("/notifications", headers=auth[0]).json() == []
    assert (
        client.patch(f"/notifications/{notification_id}/read", headers=auth[0]).status_code == 404
    )


def test_participation_counts_only_completed_assistance(journey):
    client, auth, users, rid = journey
    routes = [f"/users/{user_id}/participation" for user_id in users]

    def counts():
        values = []
        for route in routes:
            result = client.get(route, headers=auth[3])
            assert result.status_code == 200
            assert result.headers["Cache-Control"] == "no-store"
            indicator = result.json()
            assert set(indicator) == {"completed_assistance_count", "definition"}
            assert "no identity verification or safety guarantee" in indicator["definition"]
            values.append(indicator["completed_assistance_count"])
        return values

    assert client.get(routes[0]).status_code == 401
    assert client.get(f"/users/{uuid4()}/participation", headers=auth[3]).status_code == 404
    assert counts() == [0, 0, 0, 0]
    accepted = offer(client, auth[1], rid)
    assert accepted.status_code == 201
    assert offer(client, auth[2], rid).status_code == 201
    assert accept(client, auth[0], accepted.json()["id"]).status_code == 200
    assert counts() == [0, 0, 0, 0]

    for key, state, has_helper in [
        ("participation-canceled", "canceled", True),
        ("participation-unassigned", "completed", False),
    ]:
        additional = client.post(
            "/requests", headers=auth[0] | {"Idempotency-Key": key}, json=payload()
        )
        assert additional.status_code == 201
        additional_id = additional.json()["id"]
        pending = offer(client, auth[1], additional_id, key=key)
        assert pending.status_code == 201
        if has_helper:
            assert accept(client, auth[0], pending.json()["id"]).status_code == 200
        assert (
            client.patch(
                f"/requests/{additional_id}", headers=auth[0], json={"status": state}
            ).status_code
            == 200
        )
    assert counts() == [0, 0, 0, 0]

    for _ in range(2):
        assert (
            client.patch(
                f"/requests/{rid}", headers=auth[0], json={"status": "completed"}
            ).status_code
            == 200
        )
    assert counts() == [1, 1, 0, 0]
    progress_url = "/users/me/volunteer-progress"
    assert client.get(progress_url).status_code == 401
    for actor in [auth[0], auth[2], auth[3]]:
        progress = client.get(progress_url, headers=actor)
        assert progress.status_code == 200
        assert progress.json()["completed_help_count"] == 0
        assert progress.json()["earned_badges"] == []
        assert progress.json()["next_badge"]["id"] == "first_help"
    volunteer = client.get(progress_url, headers=auth[1])
    assert volunteer.status_code == 200
    assert volunteer.headers["Cache-Control"] == "no-store"
    assert volunteer.json() == {
        "completed_help_count": 1,
        "earned_badges": [{"id": "first_help", "label": "First Help", "required_completions": 1}],
        "next_badge": {"id": "helping_hand", "label": "Helping Hand", "required_completions": 5},
    }


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


def test_mvp_journey_and_third_account_boundaries(journey):
    client, auth, users, rid = journey
    owner, helper, outsider, _ = auth
    request_path = f"/requests/{rid}"
    created = offer(client, helper, rid)
    assert created.status_code == 201
    offer_id = created.json()["id"]
    assert accept(client, outsider, offer_id).status_code == 403
    assert (
        client.patch(request_path, headers=outsider, json={"title": "Changed"}).status_code == 403
    )
    assert accept(client, owner, offer_id).status_code == 200
    assert send(client, owner, rid, users[1], "Can you help?").status_code == 201
    assert send(client, helper, rid, users[0], "Yes.").status_code == 201

    message_path = f"{request_path}/messages"
    messages = client.get(message_path, headers=owner)
    assert messages.status_code == 200
    assert [message["body"] for message in messages.json()] == ["Can you help?", "Yes."]
    assert client.get(message_path, headers=helper).json() == messages.json()
    assert client.get(message_path, headers=outsider).status_code == 403
    assert client.get(message_path).status_code == 401
    completed = client.patch(request_path, headers=owner, json={"status": "completed"})
    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"

    report = {"target_type": "request", "target_id": rid, "reason": "other"}
    assert client.post("/reports", json=report).status_code == 401
    response = client.post("/reports", headers=helper, json=report)
    assert response.status_code == 201
    receipt = response.json()
    assert set(receipt) == {"id", "status"} and receipt["status"] == "pending"
    assert client.get("/reports", headers=outsider).status_code == 405
    assert client.get(f"/reports/{receipt['id']}", headers=outsider).status_code == 404


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
