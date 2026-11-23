"""Source-reviewed local resource guides maintained by release operators."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Index, Text, Uuid, false, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime


class ResourceGuide(Base):
    __tablename__ = "resource_guides"
    __table_args__ = (
        CheckConstraint("btrim(title) <> '' AND btrim(body) <> ''", name="content_present"),
        CheckConstraint("category ~ '^[a-z][a-z0-9_]{0,39}$'", name="category_format"),
        CheckConstraint("btrim(area) <> ''", name="area_present"),
        CheckConstraint(
            "source_url ~ '^https?://[^[:space:]/?#]+[^[:space:]]*$'", name="source_url_format"
        ),
        CheckConstraint("NOT published OR reviewed_at IS NOT NULL", name="published_reviewed"),
        Index(
            "ix_resource_guides_published_reviewed",
            "reviewed_at",
            "id",
            postgresql_where=text("published"),
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    title: Mapped[str] = mapped_column(Text)
    body: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(Text)
    area: Mapped[str] = mapped_column(Text)
    source_url: Mapped[str] = mapped_column(Text)
    reviewed_at: Mapped[datetime | None] = mapped_column(UTCDateTime())
    published: Mapped[bool] = mapped_column(server_default=false())
