"""An optional member photo shared only through authorized request routes."""

from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, LargeBinary, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base


class ProfilePhoto(Base):
    __tablename__ = "profile_photos"
    __table_args__ = (CheckConstraint("octet_length(jpeg) BETWEEN 1 AND 262144", name="jpeg_size"),)

    user_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("app_private.users.id", ondelete="CASCADE"), primary_key=True
    )
    jpeg: Mapped[bytes] = mapped_column(LargeBinary)
