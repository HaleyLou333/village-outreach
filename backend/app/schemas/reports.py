"""Safety report input and minimal acknowledgement."""

from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field

from app.schemas.requests import normalize_text

ReportDescription = Annotated[
    str, BeforeValidator(normalize_text), Field(strict=True, min_length=1, max_length=1000)
]


class ReportCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_type: Literal["request", "user"]
    target_id: UUID
    reason: Literal["spam", "harassment", "unsafe_content", "fraud", "other"]
    description: ReportDescription | None = None


class ReportReceipt(BaseModel):
    id: UUID
    status: Literal["pending"] = "pending"
