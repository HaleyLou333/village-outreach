"""create private help requests

Revision ID: cbcaea6d1d8d
Revises: de59b6dfa342
"""

import sqlalchemy as sa
from alembic import op

revision = "cbcaea6d1d8d"
down_revision = "de59b6dfa342"
branch_labels = None
depends_on = None


def upgrade() -> None:
    whitespace = (
        r"U&'\0009\000A\000B\000C\000D\001C\001D\001E\001F\0020\0085\00A0"
        r"\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A"
        r"\2028\2029\202F\205F\3000'"
    )
    op.create_table(
        "help_requests",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("requester_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("urgency", sa.Text(), nullable=False),
        sa.Column("latitude", sa.Float(precision=53), nullable=False),
        sa.Column("longitude", sa.Float(precision=53), nullable=False),
        sa.Column("area", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), server_default="active", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("idempotency_key", sa.Text(), nullable=False),
        sa.Column("creation_hash", sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_help_requests")),
        sa.ForeignKeyConstraint(
            ["requester_id"],
            ["app_private.users.id"],
            ondelete="RESTRICT",
            name=op.f("fk_help_requests_requester_id_users"),
        ),
        sa.UniqueConstraint(
            "requester_id", "idempotency_key", name=op.f("uq_help_requests_requester_id")
        ),
        *[
            sa.CheckConstraint(
                f"length({field}) BETWEEN 1 AND {maximum} "
                f"AND {field} = btrim({field}, {whitespace})",
                name=op.f(f"ck_help_requests_{field}_length"),
            )
            for field, maximum in (("title", 120), ("description", 4000), ("area", 100))
        ],
        sa.CheckConstraint(
            "category IN ('FOOD_ASSISTANCE', 'TRANSPORTATION', 'CHILDCARE', "
            "'DONATED_ITEMS', 'DELIVERY_HELP', 'LOCAL_SERVICES')",
            name=op.f("ck_help_requests_category_values"),
        ),
        sa.CheckConstraint(
            "urgency IN ('standard', 'time_sensitive')",
            name=op.f("ck_help_requests_urgency_values"),
        ),
        sa.CheckConstraint(
            "status IN ('active', 'completed', 'canceled')",
            name=op.f("ck_help_requests_status_values"),
        ),
        sa.CheckConstraint(
            "latitude BETWEEN -90 AND 90", name=op.f("ck_help_requests_latitude_range")
        ),
        sa.CheckConstraint(
            "longitude BETWEEN -180 AND 180", name=op.f("ck_help_requests_longitude_range")
        ),
        sa.CheckConstraint(
            "length(idempotency_key) BETWEEN 1 AND 128",
            name=op.f("ck_help_requests_idempotency_key_length"),
        ),
        sa.CheckConstraint(
            "creation_hash ~ '^[0-9a-fA-F]{64}$'",
            name=op.f("ck_help_requests_creation_hash_format"),
        ),
        schema="app_private",
    )
    op.create_index(
        "ix_help_requests_status_location",
        "help_requests",
        ["status", "latitude", "longitude"],
        schema="app_private",
    )
    op.execute("REVOKE ALL ON TABLE app_private.help_requests FROM PUBLIC")
    op.execute("""
        DO $$ BEGIN
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
                REVOKE ALL ON TABLE app_private.help_requests FROM anon;
            END IF;
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
                REVOKE ALL ON TABLE app_private.help_requests FROM authenticated;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.drop_index(
        "ix_help_requests_status_location", table_name="help_requests", schema="app_private"
    )
    op.drop_table("help_requests", schema="app_private")
