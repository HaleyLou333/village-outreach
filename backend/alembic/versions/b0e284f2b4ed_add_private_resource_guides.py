"""Add source-reviewed resource guides.

Revision ID: b0e284f2b4ed
Revises: 7bcaa4cc5f60
"""

import sqlalchemy as sa
from alembic import op

revision = "b0e284f2b4ed"
down_revision = "7bcaa4cc5f60"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "resource_guides",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("area", sa.Text(), nullable=False),
        sa.Column("source_url", sa.Text(), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.CheckConstraint(
            "btrim(title) <> '' AND btrim(body) <> ''",
            name=op.f("ck_resource_guides_content_present"),
        ),
        sa.CheckConstraint(
            "category ~ '^[a-z][a-z0-9_]{0,39}$'",
            name=op.f("ck_resource_guides_category_format"),
        ),
        sa.CheckConstraint("btrim(area) <> ''", name=op.f("ck_resource_guides_area_present")),
        sa.CheckConstraint(
            "source_url ~ '^https?://[^[:space:]/?#]+[^[:space:]]*$'",
            name=op.f("ck_resource_guides_source_url_format"),
        ),
        sa.CheckConstraint(
            "NOT published OR reviewed_at IS NOT NULL",
            name=op.f("ck_resource_guides_published_reviewed"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_resource_guides")),
        schema="app_private",
    )
    op.create_index(
        "ix_resource_guides_published_reviewed",
        "resource_guides",
        ["reviewed_at", "id"],
        schema="app_private",
        postgresql_where=sa.text("published"),
    )
    op.execute("REVOKE ALL ON TABLE app_private.resource_guides FROM PUBLIC")
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            REVOKE ALL ON TABLE app_private.resource_guides FROM anon;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            REVOKE ALL ON TABLE app_private.resource_guides FROM authenticated;
        END IF;
    END $$;""")


def downgrade() -> None:
    op.drop_table("resource_guides", schema="app_private")
