"""Application profile, separate from Supabase Auth password/session storage."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Text, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base
from app.database.types import UTCDateTime


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("length(trim(email)) BETWEEN 1 AND 254", name="email_length"),
        CheckConstraint("length(trim(display_name)) BETWEEN 1 AND 100", name="display_name_length"),
        CheckConstraint("role IN ('neighbor', 'moderator', 'admin')", name="role_values"),
        CheckConstraint("status IN ('active', 'inactive', 'suspended')", name="status_values"),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid, primary_key=True, default=uuid4, server_default=text("gen_random_uuid()")
    )
    supabase_uid: Mapped[UUID] = mapped_column(Uuid, unique=True, nullable=False)
    email: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[str] = mapped_column(Text, nullable=False, server_default="neighbor")
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), nullable=False, server_default=func.now(), onupdate=func.now()
    )
