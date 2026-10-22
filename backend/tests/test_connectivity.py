import subprocess
import sys

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import sessionmaker

from app.database.check import check_connection
from app.database.session import build_engine, session_scope

pytestmark = pytest.mark.database


def test_connectivity_query_succeeds(test_database_url):
    assert check_connection(test_database_url) is True


def test_successful_session_returns_connection(db_engine):
    checked_in = []
    from sqlalchemy import event

    event.listen(db_engine, "checkin", lambda *args: checked_in.append(True))
    factory = sessionmaker(db_engine)
    with session_scope(factory) as session:
        assert session.scalar(text("SELECT 1")) == 1
    assert checked_in
    assert not session.in_transaction()


def test_failed_transaction_rolls_back_and_next_session_works(db_engine):
    factory = sessionmaker(db_engine)
    from sqlalchemy import event

    checked_in = []
    event.listen(db_engine, "checkin", lambda *args: checked_in.append(True))
    with pytest.raises(DBAPIError), session_scope(factory) as session:
        session.execute(text("SELECT 1 / 0"))
    assert checked_in
    assert not session.in_transaction()
    with session_scope(factory) as next_session:
        assert next_session.scalar(text("SELECT 1")) == 1


def test_bad_connection_is_controlled(test_database_url):
    from sqlalchemy.engine import make_url

    # An invalid database on this disposable server, never a guessed shared server.
    bad = make_url(test_database_url).set(database="does_not_exist")
    assert check_connection(bad.render_as_string(hide_password=False)) is False


def test_connection_options_disable_prepared_statements(test_database_url):
    engine = build_engine(test_database_url)
    try:
        with engine.connect() as connection:
            assert connection.connection.driver_connection.prepare_threshold is None
            assert connection.scalar(text("SHOW statement_timeout")) is not None
    finally:
        engine.dispose()


def test_cli_failure_never_prints_credentials(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:do-not-print-me@127.0.0.1:1/absent")
    monkeypatch.setenv("ENVIRONMENT", "development")
    result = subprocess.run(
        [sys.executable, "-m", "app.database.check"], capture_output=True, text=True
    )
    assert result.returncode == 1
    assert "Database connection check failed" in result.stdout
    assert "do-not-print-me" not in result.stdout + result.stderr
    assert result.stderr == ""
