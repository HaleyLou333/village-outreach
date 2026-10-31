"""Validated request inputs and deliberately limited public responses."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, model_validator


def normalize_text(value: object) -> object:
    if isinstance(value, str):
        if "\x00" in value or any(0xD800 <= ord(char) <= 0xDFFF for char in value):
            raise ValueError("Unsupported text characters.")
        return value.strip()
    return value


Title = Annotated[
    str, BeforeValidator(normalize_text), Field(strict=True, min_length=1, max_length=120)
]
Description = Annotated[
    str, BeforeValidator(normalize_text), Field(strict=True, min_length=1, max_length=4000)
]
Area = Annotated[
    str, BeforeValidator(normalize_text), Field(strict=True, min_length=1, max_length=100)
]
Latitude = Annotated[float, Field(ge=-90, le=90, allow_inf_nan=False)]
Longitude = Annotated[float, Field(ge=-180, le=180, allow_inf_nan=False)]
Category = Literal[
    "FOOD_ASSISTANCE",
    "TRANSPORTATION",
    "CHILDCARE",
    "DONATED_ITEMS",
    "DELIVERY_HELP",
    "LOCAL_SERVICES",
]
Urgency = Literal["standard", "time_sensitive"]
Status = Literal["active", "completed", "canceled"]


class RequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Title
    description: Description
    category: Category
    urgency: Urgency
    latitude: Latitude
    longitude: Longitude
    area: Area


class RequestUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Title | None = None
    description: Description | None = None
    category: Category | None = None
    urgency: Urgency | None = None
    latitude: Latitude | None = None
    longitude: Longitude | None = None
    area: Area | None = None
    status: Status | None = None

    @model_validator(mode="after")
    def require_changes(self) -> "RequestUpdate":
        if not self.model_fields_set:
            raise ValueError("An update must contain fields.")
        if any(getattr(self, field) is None for field in self.model_fields_set):
            raise ValueError("Fields cannot be null.")
        if ("latitude" in self.model_fields_set) != ("longitude" in self.model_fields_set):
            raise ValueError("Coordinates must be supplied together.")
        return self


class RequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    requester_id: UUID
    title: str
    description: str
    category: Category
    urgency: Urgency
    latitude: float
    longitude: float
    area: str
    status: Status
    created_at: datetime
    updated_at: datetime


class FeedRequestResponse(RequestResponse):
    distance_km: float


class RequestFieldError(BaseModel):
    loc: list[str | int]
    type: str


class RequestError(BaseModel):
    detail: str
    code: str
    fields: list[RequestFieldError] | None = None
