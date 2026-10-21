import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import CheckConstraint, inspect, text

from app.database.base import Base
from tests.conftest import migration_config

pytestmark = pytest.mark.database


def test_database_check_constraint_names_match_the_model(db_engine):
    from app.models import User

    expected = {c.name for c in User.__table__.constraints if isinstance(c, CheckConstraint)}
    with db_engine.connect() as connection:
        actual = {
            c["name"]
            for c in inspect(connection).get_check_constraints("users", schema="app_private")
        }
        assert actual == expected


def test_autogenerate_leaves_unrelated_public_tables_alone(db_engine):
    with db_engine.begin() as connection:
        connection.execute(text("CREATE TABLE public.sprint1_unrelated_reference (id integer)"))
        try:
            command.check(migration_config(connection))
        finally:
            connection.execute(text("DROP TABLE public.sprint1_unrelated_reference"))


def test_upgrade_constraints_metadata_and_downgrade_reapply(db_engine):
    with db_engine.begin() as connection:
        inspector = inspect(connection)
        assert inspector.has_table("users", schema="app_private")
        assert inspector.get_pk_constraint("users", schema="app_private")[
            "constrained_columns"
        ] == ["id"]
        assert any(
            unique["column_names"] == ["supabase_uid"]
            for unique in inspector.get_unique_constraints("users", schema="app_private")
        )
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
        command.downgrade(migration_config(connection), "base")
        assert not inspect(connection).has_table("users", schema="app_private")
        command.upgrade(migration_config(connection), "head")
        assert inspect(connection).has_table("users", schema="app_private")


def test_user_table_is_not_in_public_schema(db_engine):
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT to_regclass('public.users')")) is None
        assert connection.scalar(text("SELECT to_regclass('app_private.users')")) is not None


def test_public_has_no_private_schema_or_table_privileges(db_engine):
    with db_engine.connect() as connection:
        assert (
            connection.scalar(
                text("""
            SELECT count(*) FROM pg_namespace n,
            LATERAL aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a
            WHERE n.nspname = 'app_private' AND a.grantee = 0
        """)
            )
            == 0
        )
        assert (
            connection.scalar(
                text("""
            SELECT count(*) FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace,
            LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
            WHERE n.nspname = 'app_private' AND c.relname = 'users' AND a.grantee = 0
        """)
            )
            == 0
        )
