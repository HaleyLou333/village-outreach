"""Read and update the acting user's application profile."""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, or_, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database.session import get_session
from app.models import HelpRequest, Offer, User


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


class ParticipationResponse(BaseModel):
    completed_assistance_count: int
    definition: str = (
        "Completed requests with an accepted helper, counted once per request where this member "
        "was the requester or accepted helper. This measures participation only and provides "
        "no identity verification or safety guarantee."
    )


class VolunteerBadge(BaseModel):
    id: str
    label: str
    required_completions: int


class VolunteerProgress(BaseModel):
    completed_help_count: int
    earned_badges: list[VolunteerBadge]
    next_badge: VolunteerBadge | None


VOLUNTEER_MILESTONES = (
    VolunteerBadge(id="first_help", label="First Help", required_completions=1),
    VolunteerBadge(id="helping_hand", label="Helping Hand", required_completions=5),
    VolunteerBadge(id="community_helper", label="Community Helper", required_completions=10),
)


def completed_help_query(user_id):
    return (
        select(func.count(func.distinct(HelpRequest.id)))
        .join(Offer, Offer.request_id == HelpRequest.id)
        .where(
            HelpRequest.status == "completed",
            Offer.status == "accepted",
            Offer.helper_id == user_id,
            HelpRequest.requester_id != user_id,
        )
    )


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


@router.get("/me/volunteer-progress", response_model=VolunteerProgress)
def read_volunteer_progress(user: CurrentUser, session: DatabaseSession) -> VolunteerProgress:
    """Return private recognition earned as the accepted helper on completed requests."""
    try:
        count = session.scalar(completed_help_query(user.id))
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Volunteer progress is temporarily unavailable.") from None
    return VolunteerProgress(
        completed_help_count=count,
        earned_badges=[
            badge for badge in VOLUNTEER_MILESTONES if badge.required_completions <= count
        ],
        next_badge=next(
            (badge for badge in VOLUNTEER_MILESTONES if badge.required_completions > count), None
        ),
    )


@router.get(
    "/{user_id}/participation",
    response_model=ParticipationResponse,
    responses={404: {"model": ProfileError, "description": "Active profile not found"}},
)
def read_participation(
    user_id: UUID, user: CurrentUser, session: DatabaseSession
) -> ParticipationResponse:
    """Return the public participation indicator for an active member."""
    completed = (
        select(func.count(func.distinct(HelpRequest.id)))
        .join(Offer, Offer.request_id == HelpRequest.id)
        .where(
            HelpRequest.status == "completed",
            Offer.status == "accepted",
            or_(HelpRequest.requester_id == User.id, Offer.helper_id == User.id),
        )
        .correlate(User)
        .scalar_subquery()
    )
    try:
        count = session.scalar(
            select(completed).select_from(User).where(User.id == user_id, User.status == "active")
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Participation data is temporarily unavailable.") from None
    if count is None:
        raise HTTPException(404, "Active profile not found.")
    return ParticipationResponse(completed_assistance_count=count)


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
