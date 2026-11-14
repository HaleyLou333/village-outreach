"""Real HTTP Sprint 3 smoke check using only an opted-in disposable database.

Run from backend with the README's test database environment:
    .venv/Scripts/python.exe -m scripts.verify_sprint3
No hosted Supabase data or credentials are used. Disposable signing keys stay in memory.
"""

import json
import os
import socket
import threading
import time
from datetime import UTC, datetime, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from uuid import uuid4

import jwt
import uvicorn
from alembic import command
from alembic.config import Config
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import delete, select
from sqlalchemy.orm import Session, sessionmaker

from app.auth import dependencies
from app.auth.tokens import TokenVerifier
from app.core.config import Settings
from app.database.safety import require_test_database
from app.database.session import build_engine, get_session, session_scope
from app.main import app
from app.models import HelpRequest, Message, Offer, User


def main():
    database = require_test_database(
        os.environ.get("TEST_DATABASE_URL"),
        environment=os.environ.get("ENVIRONMENT", ""),
        opt_in=os.environ.get("ALLOW_TEST_DATABASE_RESET") == "1",
    )
    engine = build_engine(database.render_as_string(hide_password=False))
    with engine.begin() as connection:
        config = Config("alembic.ini")
        config.attributes["connection"] = connection
        command.upgrade(config, "head")
    factory = sessionmaker(engine, expire_on_commit=False)

    def test_session():
        with session_scope(factory) as session:
            yield session

    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = jwt.algorithms.ECAlgorithm.to_jwk(private_key.public_key(), as_dict=True)
    public_key.update(kid="smoke-key", use="sig", alg="ES256")

    class Keys(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"keys": [public_key]}).encode())

    key_server = HTTPServer(("127.0.0.1", 0), Keys)
    key_thread = threading.Thread(target=key_server.serve_forever, daemon=True)
    key_thread.start()
    verifier = TokenVerifier(Settings(_env_file=None, supabase_url="https://smoke.example.test"))
    # Test-process-only transport override: issuer and cryptographic validation stay real.
    verifier.keys.uri = f"http://127.0.0.1:{key_server.server_port}/jwks.json"
    original_verifier = dependencies.get_token_verifier
    dependencies.get_token_verifier = lambda: verifier
    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_session] = test_session
    subjects = [uuid4() for _ in range(4)]
    now = datetime.now(UTC)
    tokens = [
        jwt.encode(
            {
                "iss": "https://smoke.example.test/auth/v1",
                "aud": "authenticated",
                "sub": str(subject),
                "email": f"smoke-{subject}@example.invalid",
                "role": "authenticated",
                "is_anonymous": False,
                "iat": int(now.timestamp()),
                "exp": int((now + timedelta(minutes=5)).timestamp()),
            },
            private_key,
            algorithm="ES256",
            headers={"kid": "smoke-key"},
        )
        for subject in subjects
    ]
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(128)
    port = listener.getsockname()[1]
    server = uvicorn.Server(
        uvicorn.Config(app, host="127.0.0.1", port=port, access_log=False, log_level="warning")
    )
    thread = threading.Thread(target=lambda: server.run(sockets=[listener]), daemon=True)
    thread.start()
    checks = []

    def call(method, path, expected, token=None, data=None, key=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        if key:
            headers["Idempotency-Key"] = key
        raw = None if data is None else json.dumps(data).encode()
        try:
            response = urlopen(
                Request(
                    f"http://127.0.0.1:{port}" + path, data=raw, headers=headers, method=method
                ),
                timeout=10,
            )
        except HTTPError as error:
            response = error
        with response:
            assert response.code == expected, (
                f"{method} endpoint returned {response.code}, expected {expected}"
            )
            return json.loads(response.read())

    def check(name, condition=True):
        assert condition, name
        checks.append(name)
        print("PASS " + name)

    try:
        deadline = time.monotonic() + 10
        while not server.started and time.monotonic() < deadline:
            time.sleep(0.02)
        assert server.started, "Temporary API did not start"
        owner, helper, other, outsider = tokens
        profiles = [call("GET", "/users/me", 200, token) for token in tokens]
        payload = {
            "title": "Synthetic Sprint 3 request",
            "description": "Disposable offer and message verification.",
            "category": "FOOD_ASSISTANCE",
            "urgency": "standard",
            "area": "Synthetic area",
            "latitude": 35.123456,
            "longitude": -97.654321,
        }
        created = call("POST", "/requests", 201, owner, payload, str(uuid4()))
        rid = created["id"]
        path = "/requests/" + rid
        offer_data = {"request_id": rid, "message": "I can help."}
        offer_key = str(uuid4())
        call("POST", "/offers", 401, data=offer_data, key=offer_key)
        check("offers require verified authentication")
        call("POST", "/offers", 403, owner, offer_data, offer_key)
        check("requester cannot offer on own request")
        first = call("POST", "/offers", 201, helper, offer_data, offer_key)
        check("offer persists verified helper identity", first["helper_id"] == profiles[1]["id"])
        replay = call("POST", "/offers", 200, helper, offer_data, offer_key)
        check("offer retry returns same record", replay == first)
        call("POST", "/offers", 409, helper, offer_data, str(uuid4()))
        check("duplicate pending offer rejected")
        second = call("POST", "/offers", 201, other, offer_data, str(uuid4()))
        visible = call("GET", path + "/offers", 200, owner)
        check("owner sees both offers", len(visible) == 2)
        check("helper sees only own offer", call("GET", path + "/offers", 200, helper) == [first])
        check(
            "unrelated user sees no private offers",
            call("GET", path + "/offers", 200, outsider) == [],
        )
        accept_path = "/offers/" + first["id"] + "/accept"
        call("POST", accept_path, 403, helper)
        check("acceptance is owner-only")
        selected = call("POST", accept_path, 200, owner)
        check("owner accepts selected helper", selected["status"] == "accepted")
        check("repeated acceptance is safe", call("POST", accept_path, 200, owner) == selected)
        call("POST", "/offers/" + second["id"] + "/accept", 409, owner)
        check("declined competing offer cannot be accepted")
        message_data = {
            "request_id": rid,
            "receiver_id": profiles[1]["id"],
            "body": "Meet at noon.",
        }
        message_key = str(uuid4())
        sent = call("POST", "/messages", 201, owner, message_data, message_key)
        check(
            "message records verified sender and receiver",
            sent["sender_id"] == profiles[0]["id"] and sent["receiver_id"] == profiles[1]["id"],
        )
        check(
            "message retry returns same record",
            call("POST", "/messages", 200, owner, message_data, message_key) == sent,
        )
        call("POST", "/messages", 409, owner, {**message_data, "body": "Changed"}, message_key)
        check("changed message cannot reuse operation key")
        call(
            "POST",
            "/messages",
            403,
            owner,
            {**message_data, "receiver_id": profiles[2]["id"]},
            str(uuid4()),
        )
        check("invalid receiver rejected")
        for token in [other, outsider]:
            call("GET", path + "/messages", 403, token)
            call("POST", "/messages", 403, token, message_data, str(uuid4()))
        check("other helpers and unrelated users cannot read or send")
        reply = call(
            "POST",
            "/messages",
            201,
            helper,
            {"request_id": rid, "receiver_id": profiles[0]["id"], "body": "Confirmed."},
            str(uuid4()),
        )
        history = call("GET", path + "/messages", 200, owner)
        check("participants retrieve ordered two-way conversation", history == [sent, reply])
        check(
            "bounded pagination returns next message",
            call("GET", path + "/messages?limit=1&offset=1", 200, helper) == [reply],
        )
        call("PATCH", path, 200, owner, {"status": "completed"})
        check(
            "both participants keep history after closure",
            call("GET", path + "/messages", 200, owner) == history
            and call("GET", path + "/messages", 200, helper) == history,
        )
        call("POST", "/messages", 409, owner, message_data, str(uuid4()))
        call("POST", "/offers", 409, outsider, offer_data, str(uuid4()))
        check("closed requests reject new messages and offers")
        with Session(engine) as session:
            offers = session.scalars(select(Offer).where(Offer.request_id == rid)).all()
            messages = session.scalars(select(Message).where(Message.request_id == rid)).all()
            check(
                "database confirms one accepted helper and one declined competitor",
                sorted(row.status for row in offers) == ["accepted", "declined"],
            )
            check("database confirms exactly two messages despite retries", len(messages) == 2)
        print(
            json.dumps(
                {
                    "result": "passed",
                    "checks": len(checks),
                    "database": "disposable loopback PostgreSQL",
                    "transport": "real loopback HTTP",
                    "hosted_data_changed": False,
                }
            )
        )
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        key_server.shutdown()
        key_server.server_close()
        key_thread.join(timeout=5)
        dependencies.get_token_verifier = original_verifier
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous_overrides)
        with engine.begin() as connection:
            user_ids = select(User.id).where(User.supabase_uid.in_(subjects))
            request_ids = select(HelpRequest.id).where(HelpRequest.requester_id.in_(user_ids))
            connection.execute(delete(Message).where(Message.request_id.in_(request_ids)))
            connection.execute(delete(Offer).where(Offer.request_id.in_(request_ids)))
            connection.execute(delete(HelpRequest).where(HelpRequest.requester_id.in_(user_ids)))
            connection.execute(delete(User).where(User.supabase_uid.in_(subjects)))
        engine.dispose()


if __name__ == "__main__":
    main()
