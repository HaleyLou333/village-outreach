"""normalize User check constraint names

Revision ID: de59b6dfa342
Revises: 45a9bab25d54
"""

from alembic import op

revision = "de59b6dfa342"
down_revision = "45a9bab25d54"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The initial revision's explicit names were prefixed again by the metadata
    # naming convention. Rename in place to preserve existing records/checks.
    for suffix in ("email_length", "display_name_length", "role_values", "status_values"):
        op.execute(
            f"ALTER TABLE app_private.users RENAME CONSTRAINT "
            f"ck_users_ck_users_{suffix} TO ck_users_{suffix}"
        )


def downgrade() -> None:
    for suffix in ("email_length", "display_name_length", "role_values", "status_values"):
        op.execute(
            f"ALTER TABLE app_private.users RENAME CONSTRAINT "
            f"ck_users_{suffix} TO ck_users_ck_users_{suffix}"
        )
