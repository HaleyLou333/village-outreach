"""Read and update the acting user's application profile."""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database.session import get_session
from app.models import User


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    display_name: str
    role: str
    status: str
    created_at: datetime
    updated_at: datetime


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: str = Field(strict=True, min_length=1, max_length=100)

    @field_validator("display_name", mode="before")
    @classmethod
    def normalize_name(cls, value: object) -> object:
        if isinstance(value, str):
            if "\x00" in value or any(0xD800 <= ord(char) <= 0xDFFF for char in value):
                raise ValueError("Display name contains unsupported characters.")
            return value.strip()
        return value


class ProfileError(BaseModel):
    detail: str


router = APIRouter(
    prefix="/users",
    tags=["Profile"],
    responses={
        401: {"model": ProfileError, "description": "Missing or invalid access token"},
        403: {"model": ProfileError, "description": "Account is not active"},
        503: {
            "model": ProfileError,
            "description": "Authentication or profile storage unavailable",
        },
    },
)
CurrentUser = Annotated[User, Depends(get_current_user)]
DatabaseSession = Annotated[Session, Depends(get_session)]


@router.get("/me", response_model=ProfileResponse)
def read_profile(user: CurrentUser) -> User:
    return user


@router.patch(
    "/me",
    response_model=ProfileResponse,
    responses={
        404: {"model": ProfileError, "description": "Profile disappeared before the update"},
        422: {"model": ProfileError, "description": "Invalid or forbidden profile fields"},
    },
)
def update_profile(
    update: ProfileUpdate, user: CurrentUser, session: DatabaseSession
) -> ProfileResponse:
    # Recheck under a row lock so deletion/status changes since authentication
    # cannot become a stale write or reactivate an account.
    try:
        profile = session.get(User, user.id, with_for_update=True, populate_existing=True)
        if profile is None:
            raise HTTPException(status_code=404, detail="Profile not found.")
        if profile.status != "active":
            raise HTTPException(status_code=403, detail="Account is not active.")
        profile.display_name = update.display_name
        session.flush()
        result = ProfileResponse.model_validate(profile)
        session.commit()
        return result
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(
            status_code=503, detail="Profile storage is temporarily unavailable."
        ) from None
