"""Credential-safe, read-only connection check: python -m app.database.check [--test]."""

import argparse
import os

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings
from app.database.safety import require_test_database
from app.database.session import build_engine, session_scope


def check_connection(value: str) -> bool:
    engine = None
    try:
        engine = build_engine(value)
        with session_scope(sessionmaker(engine)) as session:
            return session.scalar(text("SELECT 1")) == 1
    except (SQLAlchemyError, ValueError):
        return False
    finally:
        if engine is not None:
            engine.dispose()


def main() -> int:
    parser = argparse.ArgumentParser(description="Check a development PostgreSQL connection.")
    parser.add_argument("--test", action="store_true", help="Use the guarded TEST_DATABASE_URL.")
    args = parser.parse_args()
    try:
        if args.test:
            url = require_test_database(
                os.environ.get("TEST_DATABASE_URL"),
                environment=os.environ.get("ENVIRONMENT", ""),
                opt_in=os.environ.get("ALLOW_TEST_DATABASE_RESET") == "1",
            ).render_as_string(hide_password=False)
        else:
            settings = get_settings()
            if settings.environment == "production" or settings.database_url is None:
                raise ValueError
            url = settings.database_url.get_secret_value()
        success = check_connection(url)
    except ValueError:
        success = False
    print(
        "Database connection check passed (SELECT 1)."
        if success
        else "Database connection check failed; check the development connection settings."
    )
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
