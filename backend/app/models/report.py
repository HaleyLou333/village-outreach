"""Private moderation submissions with one referentially valid target."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, ForeignKey, Index, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime
from app.models.help_request import _text_constraint


class Report(Base):
    __tablename__ = "reports"
    __table_args__ = (
        CheckConstraint(
            "num_nonnulls(request_id, reported_user_id) = 1", name="exactly_one_target"
        ),
        CheckConstraint("reporter_id <> reported_user_id", name="different_users"),
        CheckConstraint(
            "reason IN ('spam', 'harassment', 'unsafe_content', 'fraud', 'other')",
            name="reason_values",
        ),
        CheckConstraint(_text_constraint("description", 1000), name="description_length"),
        CheckConstraint("status IN ('pending', 'reviewed', 'resolved')", name="status_values"),
        CheckConstraint("length(idempotency_key) BETWEEN 8 AND 128", name="idempotency_key_length"),
        CheckConstraint("creation_hash ~ '^[0-9a-f]{64}$'", name="creation_hash_format"),
        UniqueConstraint("reporter_id", "idempotency_key"),
        Index("ix_reports_request", "request_id"),
        Index("ix_reports_reported_user", "reported_user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    reporter_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT")
    )
    request_id: Mapped[UUID | None] = mapped_column(
        Uuid, ForeignKey("app_private.help_requests.id", ondelete="RESTRICT")
    )
    reported_user_id: Mapped[UUID | None] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT")
    )
    reason: Mapped[str] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default="pending")
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.clock_timestamp()
    )
    idempotency_key: Mapped[str] = mapped_column(Text)
    creation_hash: Mapped[str] = mapped_column(Text)
