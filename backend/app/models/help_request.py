"""Private, owner-scoped help requests accessed through authenticated APIs."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Float,
    ForeignKey,
    Index,
    Text,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base
from app.database.types import UTCDateTime
from app.models.user import User


def _text_constraint(field: str, maximum: int) -> str:
    # Match Python str.strip() whitespace, including Unicode area/title inputs.
    whitespace = (
        r"U&'\0009\000A\000B\000C\000D\001C\001D\001E\001F\0020\0085\00A0"
        r"\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A"
        r"\2028\2029\202F\205F\3000'"
    )
    return f"length({field}) BETWEEN 1 AND {maximum} AND {field} = btrim({field}, {whitespace})"


class HelpRequest(Base):
    __tablename__ = "help_requests"
    __table_args__ = (
        CheckConstraint(_text_constraint("title", 120), name="title_length"),
        CheckConstraint(_text_constraint("description", 4000), name="description_length"),
        CheckConstraint(_text_constraint("area", 100), name="area_length"),
        CheckConstraint(
            "category IN ('FOOD_ASSISTANCE', 'TRANSPORTATION', 'CHILDCARE', "
            "'DONATED_ITEMS', 'DELIVERY_HELP', 'LOCAL_SERVICES')",
            name="category_values",
        ),
        CheckConstraint("urgency IN ('standard', 'time_sensitive')", name="urgency_values"),
        CheckConstraint("status IN ('active', 'completed', 'canceled')", name="status_values"),
        # PostgreSQL NaN compares greater than all real values, so BETWEEN also
        # rejects NaN and both infinities, in addition to out-of-range locations.
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude_range"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude_range"),
        CheckConstraint("length(idempotency_key) BETWEEN 1 AND 128", name="idempotency_key_length"),
        CheckConstraint("creation_hash ~ '^[0-9a-fA-F]{64}$'", name="creation_hash_format"),
        UniqueConstraint("requester_id", "idempotency_key"),
        Index("ix_help_requests_status_location", "status", "latitude", "longitude"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    requester_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="RESTRICT"), nullable=False
    )
    requester: Mapped[User] = relationship(User)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    urgency: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float] = mapped_column(Float(precision=53), nullable=False)
    longitude: Mapped[float] = mapped_column(Float(precision=53), nullable=False)
    area: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), nullable=False, server_default=func.now(), onupdate=func.now()
    )
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    creation_hash: Mapped[str] = mapped_column(Text, nullable=False)
