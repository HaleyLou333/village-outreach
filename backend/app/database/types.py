from datetime import UTC, datetime

from sqlalchemy import DateTime
from sqlalchemy.types import TypeDecorator


class UTCDateTime(TypeDecorator[datetime]):
    """Store timestamptz and normalize ORM results regardless of server timezone."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if value.utcoffset() is None:
            raise ValueError("Timestamps must include a timezone.")
        return value.astimezone(UTC)

    def process_result_value(self, value, dialect):
        return value.astimezone(UTC) if value is not None else None
