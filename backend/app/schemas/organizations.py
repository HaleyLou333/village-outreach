"""Organization and membership API contracts."""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class OrganizationCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=160)


class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    is_active: bool
    created_at: datetime


class OrganizationMembershipCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    organization_id: UUID


class OrganizationMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    organization_id: UUID
    role: Literal["member", "manager", "admin"]
    approval_status: Literal["pending", "approved", "rejected"]
    created_at: datetime