"""Synchronous PostgreSQL sessions compatible with Supabase transaction pooling."""

from collections.abc import Iterator
from contextlib import contextmanager
from functools import lru_cache

from sqlalchemy import Engine, create_engine
from sqlalchemy.engine import URL, make_url
from sqlalchemy.exc import ArgumentError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import NullPool

from app.core.config import get_settings


def postgres_url(value: str) -> URL:
    """Normalize the driver without including credentials in validation errors."""
    try:
        url = make_url(value)
        if (
            url.drivername not in {"postgres", "postgresql", "postgresql+psycopg"}
            or not url.host
            or not url.database
            or not url.username
        ):
            raise ValueError
        return url.set(drivername="postgresql+psycopg")
    except (ArgumentError, ValueError, TypeError):
        raise ValueError("A valid PostgreSQL connection URL is required.") from None


def build_engine(value: str) -> Engine:
    """Use Supabase's pooler, with a bounded connection attempt and no SQL logging."""
    return create_engine(
        postgres_url(value),
        poolclass=NullPool,
        connect_args={"prepare_threshold": None, "connect_timeout": 5},
        hide_parameters=True,
        echo=False,
    )


@lru_cache
def get_engine() -> Engine:
    settings = get_settings()
    if settings.database_url is None:
        raise ValueError("DATABASE_URL is not configured.")
    return build_engine(settings.database_url.get_secret_value())


@contextmanager
def session_scope(factory: sessionmaker[Session]) -> Iterator[Session]:
    """Callers explicitly commit writes; every exit rolls back pending work and closes."""
    with factory() as session:
        try:
            yield session
        finally:
            session.rollback()


def get_session() -> Iterator[Session]:
    """Provide a session; route dependencies verify identity and callers commit writes."""
    factory = sessionmaker(get_engine(), expire_on_commit=False)
    with session_scope(factory) as session:
        yield session
