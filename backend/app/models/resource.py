"""Team-maintained community service locations."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Float, Index, Text, Uuid, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime
from app.models.help_request import _text_constraint


class Resource(Base):
    __tablename__ = "resources"
    __table_args__ = (
        CheckConstraint(_text_constraint("name", 160), name="name_length"),
        CheckConstraint(_text_constraint("area", 100), name="area_length"),
        CheckConstraint(_text_constraint("address", 300), name="address_length"),
        CheckConstraint("category ~ '^[a-z][a-z0-9_]{0,39}$'", name="category_format"),
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude_range"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude_range"),
        CheckConstraint(_text_constraint("source_url", 2048), name="source_url_length"),
        CheckConstraint("source_url ~ '^https?://[^[:space:]]+$'", name="source_url_format"),
        CheckConstraint(_text_constraint("phone", 40), name="phone_length"),
        CheckConstraint(_text_constraint("website", 2048), name="website_length"),
        CheckConstraint("website ~ '^https?://[^[:space:]]+$'", name="website_format"),
        Index("ix_resources_organization", "organization_id"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    name: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(Text)
    area: Mapped[str] = mapped_column(Text)
    address: Mapped[str] = mapped_column(Text)
    latitude: Mapped[float] = mapped_column(Float(precision=53))
    longitude: Mapped[float] = mapped_column(Float(precision=53))
    phone: Mapped[str | None] = mapped_column(Text)
    website: Mapped[str | None] = mapped_column(Text)
    source_url: Mapped[str] = mapped_column(Text)
    last_verified_at: Mapped[datetime] = mapped_column(UTCDateTime())
    is_active: Mapped[bool] = mapped_column(server_default=text("true"))
    # CCVO-77 owns the future organization table and foreign key.
    organization_id: Mapped[UUID | None] = mapped_column(Uuid)
