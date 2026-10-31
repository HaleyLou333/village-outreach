"""Real HTTP Sprint 2 smoke check using only an opted-in disposable database.

Run from backend with the README's test database environment:
    .venv/Scripts/python.exe -m scripts.verify_sprint2
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
from app.models import HelpRequest, User


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
    subjects = [uuid4(), uuid4()]
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
        a, b = tokens
        call("GET", "/health", 200)
        call("GET", "/requests?latitude=35&longitude=-97", 401)
        check("running HTTP server and unauthenticated rejection")
        first_profile = call("GET", "/users/me", 200, a)
        call("PATCH", "/users/me", 200, a, {"display_name": "Smoke Neighbor"})
        check(
            "profile read and saved update",
            call("GET", "/users/me", 200, a)["display_name"] == "Smoke Neighbor",
        )
        call("GET", "/users/me", 200, b)
        payload = {
            "title": "Synthetic smoke request",
            "description": "Disposable integration test.",
            "category": "FOOD_ASSISTANCE",
            "urgency": "standard",
            "area": "Synthetic area",
            "latitude": 35.123456,
            "longitude": -97.654321,
        }
        key = str(uuid4())
        created = call("POST", "/requests", 201, a, payload, key)
        check("create owned request", created["requester_id"] == first_profile["id"])
        replay = call("POST", "/requests", 200, a, payload, key)
        check("exact operation retry returns the same request", replay["id"] == created["id"])
        call("POST", "/requests", 409, a, {**payload, "title": "Different operation"}, key)
        check("different payload cannot reuse the operation key")
        path = "/requests/" + created["id"]
        detail = call("GET", path, 200, b)
        check(
            "detail exposes approximate coordinates only",
            detail["latitude"] == 35.12
            and detail["longitude"] == -97.65
            and "creation_hash" not in detail,
        )
        call("PATCH", path, 403, b, {"status": "completed"})
        check("second user cannot complete the owner's request")
        call("PATCH", path, 200, a, {"description": "Updated synthetic test."})
        check(
            "owner update persists",
            call("GET", path, 200, a)["description"] == "Updated synthetic test.",
        )
        feed_path = (
            "/requests?latitude=35.123456&longitude=-97.654321&radius_km=1&limit=100&offset=0"
        )
        check(
            "nearby active request appears in feed",
            created["id"] in {item["id"] for item in call("GET", feed_path, 200, b)},
        )
        call("PATCH", path, 200, a, {"status": "completed"})
        check(
            "completion persists and removes active-feed entry",
            call("GET", path, 200, a)["status"] == "completed"
            and created["id"] not in {item["id"] for item in call("GET", feed_path, 200, b)},
        )
        call("PATCH", path, 200, a, {"status": "completed"})
        call("PATCH", path, 409, a, {"status": "active"})
        call("PATCH", path, 409, a, {"title": "Cannot edit closed record"})
        check("completion retry is safe; reopening and closed edits rejected")
        cancel = call("POST", "/requests", 201, a, payload, str(uuid4()))
        call("PATCH", "/requests/" + cancel["id"], 200, a, {"status": "canceled"})
        check(
            "cancellation persists and leaves the active feed",
            cancel["id"] not in {item["id"] for item in call("GET", feed_path, 200, b)},
        )
        with Session(engine) as session:
            rows = session.scalars(
                select(HelpRequest).where(HelpRequest.requester_id == first_profile["id"])
            ).all()
            check(
                "database confirms exactly two persisted closed requests",
                len(rows) == 2 and {row.status for row in rows} == {"completed", "canceled"},
            )
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
            connection.execute(delete(HelpRequest).where(HelpRequest.requester_id.in_(user_ids)))
            connection.execute(delete(User).where(User.supabase_uid.in_(subjects)))
        engine.dispose()


if __name__ == "__main__":
    main()
