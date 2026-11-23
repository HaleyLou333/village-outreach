"""Add private notification inboxes.

Revision ID: 7bcaa4cc5f60
Revises: b47ea3f6b35f
"""

import sqlalchemy as sa
from alembic import op

revision = "7bcaa4cc5f60"
down_revision = "b47ea3f6b35f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("recipient_id", sa.Uuid(), nullable=False),
        sa.Column("request_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("clock_timestamp()"),
            nullable=False,
        ),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "type IN ('offer_received', 'offer_accepted', 'message_received')",
            name=op.f("ck_notifications_type_values"),
        ),
        sa.ForeignKeyConstraint(
            ["recipient_id"],
            ["app_private.users.id"],
            name=op.f("fk_notifications_recipient_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["request_id"],
            ["app_private.help_requests.id"],
            name=op.f("fk_notifications_request_id_help_requests"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notifications")),
        schema="app_private",
    )
    op.create_index(
        "ix_notifications_recipient_id", "notifications", ["recipient_id"], schema="app_private"
    )
    op.create_index(
        "ix_notifications_request_id", "notifications", ["request_id"], schema="app_private"
    )
    op.execute("REVOKE ALL ON TABLE app_private.notifications FROM PUBLIC")
    op.execute("""DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            REVOKE ALL ON TABLE app_private.notifications FROM anon;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            REVOKE ALL ON TABLE app_private.notifications FROM authenticated;
        END IF;
    END $$;""")


def downgrade() -> None:
    op.drop_table("notifications", schema="app_private")
