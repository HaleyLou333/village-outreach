"""Fail closed before tests or destructive migration checks open a connection."""

import os

from sqlalchemy.engine import URL

from app.database.session import postgres_url


def require_test_database(value: str | None, *, environment: str, opt_in: bool) -> URL:
    message = (
        "Tests require ENVIRONMENT=test, ALLOW_TEST_DATABASE_RESET=1, and a "
        "TEST_DATABASE_URL for a disposable loopback PostgreSQL database ending in _test."
    )
    if environment != "test" or not opt_in or not value:
        raise ValueError(message)
    url = postgres_url(value)
    if (
        url.host not in {"localhost", "127.0.0.1", "::1"}
        or not url.database.endswith("_test")
        or url.query
        or any(
            os.environ.get(key) for key in ("PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS")
        )
    ):
        raise ValueError(message)
    for key in ("DATABASE_URL", "MIGRATION_DATABASE_URL"):
        configured = os.environ.get(key)
        if configured:
            other = postgres_url(configured)
            loopback = {"localhost", "127.0.0.1", "::1"}
            same_host = other.host == url.host or other.host in loopback
            if (
                same_host
                and (other.port or 5432) == (url.port or 5432)
                and other.database == url.database
            ):
                raise ValueError(
                    "The disposable test database must differ from application targets."
                )
    return url
