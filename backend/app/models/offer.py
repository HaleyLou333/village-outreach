"""Private helper offers and database-enforced assignment uniqueness."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, ForeignKey, Index, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime
from app.models.help_request import _text_constraint


class Offer(Base):
    __tablename__ = "offers"
    __table_args__ = (
        CheckConstraint(_text_constraint("message", 4000), name="message_length"),
        CheckConstraint(
            "status IN ('pending', 'accepted', 'declined', 'withdrawn')", name="status_values"
        ),
        CheckConstraint("length(idempotency_key) BETWEEN 8 AND 128", name="idempotency_key_length"),
        CheckConstraint("creation_hash ~ '^[0-9a-f]{64}$'", name="creation_hash_format"),
        UniqueConstraint("helper_id", "idempotency_key"),
        Index(
            "uq_offers_pending_helper_request",
            "request_id",
            "helper_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
        ),
        Index(
            "uq_offers_accepted_request",
            "request_id",
            unique=True,
            postgresql_where=text("status = 'accepted'"),
        ),
        Index("ix_offers_request_created", "request_id", "created_at", "id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    request_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.help_requests.id", ondelete="RESTRICT")
    )
    helper_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT")
    )
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default="pending")
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.clock_timestamp()
    )
    idempotency_key: Mapped[str] = mapped_column(Text)
    creation_hash: Mapped[str] = mapped_column(Text)
