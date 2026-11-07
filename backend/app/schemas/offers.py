"""Offer input and public-to-participants response contract."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.requests import Description


class OfferCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    message: Description


class OfferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    request_id: UUID
    helper_id: UUID
    message: str
    status: Literal["pending", "accepted", "declined", "withdrawn"]
    created_at: datetime
