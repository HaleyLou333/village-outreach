"""Add private member profile photos.

Revision ID: e671d6f9a2b0
Revises: b0e284f2b4ed
"""

import sqlalchemy as sa
from alembic import op

revision = "e671d6f9a2b0"
down_revision = "b0e284f2b4ed"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "profile_photos",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("jpeg", sa.LargeBinary(), nullable=False),
        sa.CheckConstraint(
            "octet_length(jpeg) BETWEEN 1 AND 262144", name=op.f("ck_profile_photos_jpeg_size")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["app_private.users.id"],
            name=op.f("fk_profile_photos_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_profile_photos")),
        schema="app_private",
    )
    op.execute("REVOKE ALL ON TABLE app_private.profile_photos FROM PUBLIC")
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            REVOKE ALL ON TABLE app_private.profile_photos FROM anon;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            REVOKE ALL ON TABLE app_private.profile_photos FROM authenticated;
        END IF;
    END $$;""")


def downgrade() -> None:
    op.drop_table("profile_photos", schema="app_private")
