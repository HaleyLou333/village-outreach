from uuid import uuid4

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import inspect, text

from app.database.base import Base
from tests.conftest import migration_config

pytestmark = pytest.mark.database


def test_help_request_migration_downgrade_preserves_users_and_reapplies(db_engine):
    owner_id, auth_id = uuid4(), uuid4()
    with db_engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO app_private.users (id, supabase_uid, email, display_name) "
                "VALUES (:id, :auth, 'migration@example.com', 'Migration')"
            ),
            {"id": owner_id, "auth": auth_id},
        )
        assert inspect(connection).has_table("help_requests", schema="app_private")
        command.downgrade(migration_config(connection), "de59b6dfa342")
        assert not inspect(connection).has_table("help_requests", schema="app_private")
        assert (
            connection.scalar(
                text("SELECT display_name FROM app_private.users WHERE id=:id"), {"id": owner_id}
            )
            == "Migration"
        )
        command.upgrade(migration_config(connection), "head")
        context = MigrationContext.configure(
            connection,
            opts={
                "include_schemas": True,
                "include_name": lambda name, kind, parent: (
                    name == "app_private" if kind == "schema" else True
                ),
                "compare_server_default": True,
            },
        )
        assert compare_metadata(context, Base.metadata) == []
        indexes = inspect(connection).get_indexes("help_requests", schema="app_private")
        assert any(
            index["column_names"] == ["status", "latitude", "longitude"] for index in indexes
        )
        connection.execute(text("DELETE FROM app_private.users WHERE id=:id"), {"id": owner_id})


def test_help_requests_are_private_from_public_and_supabase_roles(db_engine):
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT to_regclass('public.help_requests')")) is None
        assert (
            connection.scalar(text("SELECT to_regclass('app_private.help_requests')")) is not None
        )
        assert (
            connection.scalar(
                text("""
            SELECT count(*) FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace,
            LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
            WHERE n.nspname='app_private' AND c.relname='help_requests'
              AND (a.grantee=0 OR a.grantee IN
                   (SELECT oid FROM pg_roles WHERE rolname IN ('anon', 'authenticated')))
        """)
            )
            == 0
        )
