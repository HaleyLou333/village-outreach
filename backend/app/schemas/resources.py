"""Resource filters and public location data."""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.requests import Area, Latitude, Longitude

ResourceCategory = Annotated[str, Field(pattern=r"^[a-z][a-z0-9_]{0,39}$")]


class ResourceQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category: ResourceCategory | None = None
    area: Area | None = None
    latitude: Latitude | None = None
    longitude: Longitude | None = None
    radius_km: Annotated[float, Field(gt=0, le=100, allow_inf_nan=False)] | None = None
    limit: Annotated[int, Field(ge=1, le=100)] = 20
    offset: Annotated[int, Field(ge=0, le=10000)] = 0

    @model_validator(mode="after")
    def validate_location(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Coordinates must be supplied together.")
        if self.radius_km is not None and self.latitude is None:
            raise ValueError("Radius requires coordinates.")
        return self


class ResourceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    category: str
    area: str
    address: str
    latitude: float
    longitude: float
    phone: str | None
    website: str | None
    source_url: str
    last_verified_at: datetime
