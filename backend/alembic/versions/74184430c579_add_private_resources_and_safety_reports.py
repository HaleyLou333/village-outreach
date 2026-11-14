"""add private resources and safety reports

Revision ID: 74184430c579
Revises: 1b906b3ac8e0
"""

import sqlalchemy as sa
from alembic import op

revision = "74184430c579"
down_revision = "1b906b3ac8e0"
branch_labels = None
depends_on = None


def trimmed_text(field: str, maximum: int) -> str:
    # Keep this snapshot independent of application model changes.
    whitespace = (
        r"U&'\0009\000A\000B\000C\000D\001C\001D\001E\001F\0020\0085\00A0"
        r"\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A"
        r"\2028\2029\202F\205F\3000'"
    )
    return f"length({field}) BETWEEN 1 AND {maximum} AND {field} = btrim({field}, {whitespace})"


def upgrade() -> None:
    op.create_table(
        "resources",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("area", sa.Text(), nullable=False),
        sa.Column("address", sa.Text(), nullable=False),
        sa.Column("latitude", sa.Float(precision=53), nullable=False),
        sa.Column("longitude", sa.Float(precision=53), nullable=False),
        sa.Column("phone", sa.Text(), nullable=True),
        sa.Column("website", sa.Text(), nullable=True),
        sa.Column("source_url", sa.Text(), nullable=False),
        sa.Column("last_verified_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("organization_id", sa.Uuid(), nullable=True),
        sa.CheckConstraint(
            "category ~ '^[a-z][a-z0-9_]{0,39}$'", name=op.f("ck_resources_category_format")
        ),
        sa.CheckConstraint(
            trimmed_text("address", 300),
            name=op.f("ck_resources_address_length"),
        ),
        sa.CheckConstraint(
            trimmed_text("area", 100),
            name=op.f("ck_resources_area_length"),
        ),
        sa.CheckConstraint(
            trimmed_text("name", 160),
            name=op.f("ck_resources_name_length"),
        ),
        sa.CheckConstraint(
            trimmed_text("phone", 40),
            name=op.f("ck_resources_phone_length"),
        ),
        sa.CheckConstraint(
            trimmed_text("source_url", 2048),
            name=op.f("ck_resources_source_url_length"),
        ),
        sa.CheckConstraint(
            trimmed_text("website", 2048),
            name=op.f("ck_resources_website_length"),
        ),
        sa.CheckConstraint(
            "source_url ~ '^https?://[^[:space:]]+$'", name=op.f("ck_resources_source_url_format")
        ),
        sa.CheckConstraint(
            "website ~ '^https?://[^[:space:]]+$'", name=op.f("ck_resources_website_format")
        ),
        sa.CheckConstraint("latitude BETWEEN -90 AND 90", name=op.f("ck_resources_latitude_range")),
        sa.CheckConstraint(
            "longitude BETWEEN -180 AND 180", name=op.f("ck_resources_longitude_range")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_resources")),
        schema="app_private",
    )
    op.create_index(
        "ix_resources_organization",
        "resources",
        ["organization_id"],
        unique=False,
        schema="app_private",
    )
    op.create_table(
        "reports",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("reporter_id", sa.Uuid(), nullable=False),
        sa.Column("request_id", sa.Uuid(), nullable=True),
        sa.Column("reported_user_id", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.Text(), server_default="pending", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("clock_timestamp()"),
            nullable=False,
        ),
        sa.Column("idempotency_key", sa.Text(), nullable=False),
        sa.Column("creation_hash", sa.Text(), nullable=False),
        sa.CheckConstraint(
            "creation_hash ~ '^[0-9a-f]{64}$'", name=op.f("ck_reports_creation_hash_format")
        ),
        sa.CheckConstraint(
            trimmed_text("description", 1000),
            name=op.f("ck_reports_description_length"),
        ),
        sa.CheckConstraint(
            "reason IN ('spam', 'harassment', 'unsafe_content', 'fraud', 'other')",
            name=op.f("ck_reports_reason_values"),
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'reviewed', 'resolved')", name=op.f("ck_reports_status_values")
        ),
        sa.CheckConstraint(
            "length(idempotency_key) BETWEEN 8 AND 128",
            name=op.f("ck_reports_idempotency_key_length"),
        ),
        sa.CheckConstraint(
            "num_nonnulls(request_id, reported_user_id) = 1",
            name=op.f("ck_reports_exactly_one_target"),
        ),
        sa.CheckConstraint(
            "reporter_id <> reported_user_id", name=op.f("ck_reports_different_users")
        ),
        sa.ForeignKeyConstraint(
            ["reported_user_id"],
            ["app_private.users.id"],
            name=op.f("fk_reports_reported_user_id_users"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["reporter_id"],
            ["app_private.users.id"],
            name=op.f("fk_reports_reporter_id_users"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["request_id"],
            ["app_private.help_requests.id"],
            name=op.f("fk_reports_request_id_help_requests"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_reports")),
        sa.UniqueConstraint("reporter_id", "idempotency_key", name=op.f("uq_reports_reporter_id")),
        schema="app_private",
    )
    op.create_index(
        "ix_reports_reported_user",
        "reports",
        ["reported_user_id"],
        unique=False,
        schema="app_private",
    )
    op.create_index(
        "ix_reports_request", "reports", ["request_id"], unique=False, schema="app_private"
    )

    op.execute("REVOKE ALL ON TABLE app_private.resources, app_private.reports FROM PUBLIC")
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            REVOKE ALL ON TABLE app_private.resources, app_private.reports FROM anon;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            REVOKE ALL ON TABLE app_private.resources, app_private.reports FROM authenticated;
        END IF;
    END $$;""")


def downgrade() -> None:
    op.drop_index("ix_reports_request", table_name="reports", schema="app_private")
    op.drop_index("ix_reports_reported_user", table_name="reports", schema="app_private")
    op.drop_table("reports", schema="app_private")
    op.drop_index("ix_resources_organization", table_name="resources", schema="app_private")
    op.drop_table("resources", schema="app_private")
