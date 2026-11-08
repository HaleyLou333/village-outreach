"""Persisted request conversation records; authorization lives in services."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, ForeignKey, Index, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime
from app.models.help_request import _text_constraint


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        CheckConstraint(_text_constraint("body", 4000), name="body_length"),
        CheckConstraint("sender_id <> receiver_id", name="different_participants"),
        CheckConstraint("length(idempotency_key) BETWEEN 8 AND 128", name="idempotency_key_length"),
        CheckConstraint("creation_hash ~ '^[0-9a-f]{64}$'", name="creation_hash_format"),
        UniqueConstraint("sender_id", "idempotency_key"),
        Index("ix_messages_request_created", "request_id", "created_at", "id"),
        Index("ix_messages_receiver", "receiver_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    request_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.help_requests.id", ondelete="RESTRICT")
    )
    sender_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT")
    )
    receiver_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT")
    )
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.clock_timestamp()
    )
    idempotency_key: Mapped[str] = mapped_column(Text)
    creation_hash: Mapped[str] = mapped_column(Text)
