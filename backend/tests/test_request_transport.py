import logging
from uuid import UUID

from fastapi.testclient import TestClient

from app.main import app


def test_profile_storage_outage_returns_generic_503(monkeypatch, verifier, claims, signing_key):
    from sqlalchemy.exc import OperationalError
    from sqlalchemy.orm import Session

    from app.auth import dependencies
    from app.database.session import get_session
    from tests.auth_helpers import encode

    def unavailable(*_):
        raise OperationalError("private statement", {}, RuntimeError("private upstream detail"))

    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    monkeypatch.setattr(dependencies, "resolve_user", unavailable)
    previous = app.dependency_overrides.copy()
    with Session() as session:
        app.dependency_overrides[get_session] = lambda: session
        try:
            with TestClient(app, raise_server_exceptions=False) as client:
                response = client.get(
                    "/requests?latitude=35&longitude=-97",
                    headers={"Authorization": "Bearer " + encode(claims, signing_key)},
                )
            assert response.status_code == 503
            assert response.json()["code"] == "service_unavailable"
            assert "private" not in response.text
        finally:
            app.dependency_overrides.clear()
            app.dependency_overrides.update(previous)


def test_request_auth_errors_have_stable_code_and_request_id():
    with TestClient(app) as client:
        response = client.get(
            "/requests?latitude=35&longitude=-97", headers={"X-Request-ID": "caller"}
        )
    assert response.status_code == 401
    assert response.json() == {
        "detail": "Invalid or missing access token.",
        "code": "unauthenticated",
    }
    assert UUID(response.headers["x-request-id"])
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.headers["cache-control"] == "no-store"


def test_malformed_request_body_does_not_echo_private_input():
    with TestClient(app) as client:
        response = client.post(
            "/requests",
            content='{"secret precise location',
            headers={"Content-Type": "application/json"},
        )
    assert response.status_code == 422
    assert response.json()["code"] == "invalid_request"
    assert response.json()["fields"]
    assert "secret precise location" not in response.text


def test_request_logs_omit_query_location_and_credentials(caplog):
    with caplog.at_level(logging.INFO, logger="app.http"), TestClient(app) as client:
        response = client.get("/requests?latitude=35.123456&longitude=-97.654321")
    messages = [record.getMessage() for record in caplog.records if record.name == "app.http"]
    assert len(messages) == 1
    assert response.headers["x-request-id"] in messages[0]
    assert "status=401" in messages[0]
    assert "35.123456" not in messages[0]
    assert "97.654321" not in messages[0]


def test_profile_error_contract_stays_compatible():
    with TestClient(app) as client:
        response = client.get("/users/me")
    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid or missing access token."}
