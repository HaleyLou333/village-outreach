from fastapi.testclient import TestClient

from app.main import app


def test_application_startup_health_and_openapi():
    with TestClient(app) as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
        assert "/health" in client.get("/openapi.json").json()["paths"]


def test_health_does_not_need_database_credentials(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with TestClient(app) as client:
        assert client.get("/health").status_code == 200
