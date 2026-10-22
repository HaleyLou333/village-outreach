import pytest
from sqlalchemy import text

from app.core import config
from app.database import session as database


def test_missing_runtime_database_is_a_clear_error(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setattr(config.Settings, "model_config", {"env_file": None})
    config.get_settings.cache_clear()
    database.get_engine.cache_clear()
    try:
        with pytest.raises(ValueError, match="DATABASE_URL is not configured"):
            database.get_engine()
    finally:
        config.get_settings.cache_clear()
        database.get_engine.cache_clear()


@pytest.mark.database
def test_fastapi_session_dependency_closes_connection(db_engine, monkeypatch):
    monkeypatch.setattr(database, "get_engine", lambda: db_engine)
    dependency = database.get_session()
    session = next(dependency)
    assert session.scalar(text("SELECT 1")) == 1
    dependency.close()
    assert not session.in_transaction()
