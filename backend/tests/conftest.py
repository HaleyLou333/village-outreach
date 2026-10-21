import os
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy.orm import Session

from app.database.safety import require_test_database
from app.database.session import build_engine

BACKEND = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="session")
def test_database_url():
    try:
        url = require_test_database(
            os.environ.get("TEST_DATABASE_URL"),
            environment=os.environ.get("ENVIRONMENT", ""),
            opt_in=os.environ.get("ALLOW_TEST_DATABASE_RESET") == "1",
        )
    except ValueError as error:
        pytest.fail(str(error), pytrace=False)
    return url.render_as_string(hide_password=False)


def migration_config(connection):
    config = Config(str(BACKEND / "alembic.ini"))
    config.attributes["connection"] = connection
    return config


@pytest.fixture(scope="session")
def db_engine(test_database_url):
    engine = build_engine(test_database_url)
    try:
        with engine.begin() as connection:
            command.upgrade(migration_config(connection), "head")
        yield engine
    finally:
        engine.dispose()


@pytest.fixture
def db_session(db_engine):
    with db_engine.connect() as connection:
        transaction = connection.begin()
        with Session(bind=connection, join_transaction_mode="create_savepoint") as session:
            yield session
        transaction.rollback()
