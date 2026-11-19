"""Private in-app events for a single recipient."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, ForeignKey, Index, Text, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        CheckConstraint(
            "type IN ('offer_received', 'offer_accepted', 'message_received')", name="type_values"
        ),
        Index("ix_notifications_recipient_id", "recipient_id"),
        Index("ix_notifications_request_id", "request_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    recipient_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="CASCADE")
    )
    request_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.help_requests.id", ondelete="CASCADE")
    )
    type: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.clock_timestamp()
    )
    read_at: Mapped[datetime | None] = mapped_column(UTCDateTime())
