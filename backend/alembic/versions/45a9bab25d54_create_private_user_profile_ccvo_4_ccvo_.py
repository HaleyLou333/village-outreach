"""create private User profile (CCVO-4 CCVO-28)

Revision ID: 45a9bab25d54
Revises:
"""

import sqlalchemy as sa
from alembic import op

revision = "45a9bab25d54"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE SCHEMA IF NOT EXISTS app_private")
    op.execute("REVOKE ALL ON SCHEMA app_private FROM PUBLIC")
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("supabase_uid", sa.Uuid(), nullable=False),
        sa.Column("email", sa.Text(), nullable=False),
        sa.Column("display_name", sa.Text(), nullable=False),
        sa.Column("role", sa.Text(), server_default="neighbor", nullable=False),
        sa.Column("status", sa.Text(), server_default="active", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("supabase_uid", name="uq_users_supabase_uid"),
        sa.CheckConstraint("length(trim(email)) BETWEEN 1 AND 254", name="ck_users_email_length"),
        sa.CheckConstraint(
            "length(trim(display_name)) BETWEEN 1 AND 100", name="ck_users_display_name_length"
        ),
        sa.CheckConstraint(
            "role IN ('neighbor', 'moderator', 'admin')", name="ck_users_role_values"
        ),
        sa.CheckConstraint(
            "status IN ('active', 'inactive', 'suspended')", name="ck_users_status_values"
        ),
        schema="app_private",
    )
    op.execute("REVOKE ALL ON TABLE app_private.users FROM PUBLIC")
    # Supabase can grant default table access to these roles. This also works on
    # standalone PostgreSQL where those hosted-service roles do not exist.
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
                REVOKE ALL ON SCHEMA app_private FROM anon;
                REVOKE ALL ON TABLE app_private.users FROM anon;
            END IF;
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
                REVOKE ALL ON SCHEMA app_private FROM authenticated;
                REVOKE ALL ON TABLE app_private.users FROM authenticated;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.drop_table("users", schema="app_private")
    # Leave the schema itself: future migrations or pre-existing private tables
    # may share it. Never cascade-delete a shared schema.
