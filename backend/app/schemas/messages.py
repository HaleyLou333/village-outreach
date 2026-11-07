"""Conversation input and participant-only response contract."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.requests import Description


class MessageCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    receiver_id: UUID
    body: Description


class MessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    request_id: UUID
    sender_id: UUID
    receiver_id: UUID
    body: str
    created_at: datetime
