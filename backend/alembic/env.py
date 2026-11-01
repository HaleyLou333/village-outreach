"""Alembic is an explicit command, never an application startup side effect."""

from alembic import context

from app.core.config import get_settings
from app.database.base import APP_SCHEMA, Base
from app.database.session import build_engine, postgres_url
from app.models import HelpRequest, User  # noqa: F401 - register metadata for autogenerate

config = context.config


def include_name(name, type_, parent_names):
    # None is PostgreSQL's default/public schema. Supabase owns tables there;
    # reflecting it would propose deleting tables not represented in our models.
    return name == APP_SCHEMA if type_ == "schema" else True


def run_with_connection(connection):
    context.configure(
        connection=connection,
        target_metadata=Base.metadata,
        include_schemas=True,
        include_name=include_name,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def migration_url() -> str:
    settings = get_settings()
    if settings.migration_database_url is None:
        raise ValueError("MIGRATION_DATABASE_URL is required; no runtime URL fallback is allowed.")
    value = settings.migration_database_url.get_secret_value()
    if postgres_url(value).port == 6543:
        raise ValueError(
            "Migrations require a direct/session connection, not a transaction pooler."
        )
    return value


if context.is_offline_mode():
    context.configure(
        url=postgres_url(migration_url()),
        target_metadata=Base.metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=True,
    )
    with context.begin_transaction():
        context.run_migrations()
elif config.attributes.get("connection") is not None:
    run_with_connection(config.attributes["connection"])
else:
    engine = build_engine(migration_url())
    try:
        with engine.connect() as connection:
            run_with_connection(connection)
    finally:
        engine.dispose()
