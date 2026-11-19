"""Recipient-scoped inbox and read receipts."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database.session import get_session
from app.models import Notification, User

router = APIRouter(prefix="/notifications", tags=["Notifications"])
CurrentUser = Annotated[User, Depends(get_current_user)]
DatabaseSession = Annotated[Session, Depends(get_session)]


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    request_id: UUID
    type: Literal["offer_received", "offer_accepted", "message_received"]
    created_at: datetime
    read_at: datetime | None


def inbox(user_id: UUID):
    return select(Notification).where(Notification.recipient_id == user_id)


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    user: CurrentUser,
    session: DatabaseSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
) -> list[NotificationResponse]:
    """List unread events first, with newest events first within each group."""
    try:
        rows = session.scalars(
            inbox(user.id)
            .order_by(
                Notification.read_at.is_not(None),
                Notification.created_at.desc(),
                Notification.id.desc(),
            )
            .limit(limit)
            .offset(offset)
        )
        return [NotificationResponse.model_validate(row) for row in rows]
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Notifications are temporarily unavailable.") from None


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: UUID, user: CurrentUser, session: DatabaseSession
) -> NotificationResponse:
    """Set the read timestamp once. Return 404 for unavailable events."""
    try:
        row = session.scalar(
            inbox(user.id)
            .where(Notification.id == notification_id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if row is None:
            raise HTTPException(404, "Notification not found.")
        if row.read_at is None:
            row.read_at = session.scalar(select(func.clock_timestamp()))
        result = NotificationResponse.model_validate(row)
        session.commit()
        return result
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Notifications are temporarily unavailable.") from None
