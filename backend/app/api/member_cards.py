"""Member cards disclosed only to people connected by a request or accepted offer."""

from base64 import b64decode, b64encode
from binascii import Error as Base64Error
from io import BytesIO
from uuid import UUID

from fastapi import APIRouter, HTTPException, Response
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError

from app.api.profiles import (
    VOLUNTEER_MILESTONES,
    CurrentUser,
    DatabaseSession,
    completed_help_query,
)
from app.models import HelpRequest, Offer, ProfilePhoto, User

router = APIRouter(tags=["Member Cards"])
MAX_ENCODED_BYTES = 4 * ((256 * 1024 + 2) // 3)


class PhotoUpload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    photo: str = Field(min_length=4, max_length=MAX_ENCODED_BYTES)


class PhotoResponse(BaseModel):
    photo: str | None


class MemberCard(PhotoResponse):
    display_name: str
    completed_help_count: int
    badges: list[str]


def normalized_jpeg(encoded: str) -> bytes:
    try:
        raw = b64decode(encoded, validate=True)
        if len(raw) > 256 * 1024:
            raise ValueError
        with Image.open(BytesIO(raw), formats=("JPEG", "PNG", "WEBP")) as image:
            if max(image.size) > 2048 or getattr(image, "is_animated", False):
                raise ValueError
            oriented = ImageOps.exif_transpose(image).convert("RGB")
            oriented.thumbnail((384, 384))
            output = BytesIO()
            # Encode pixels into a fresh image so location and camera metadata are discarded.
            clean = Image.new("RGB", oriented.size)
            clean.paste(oriented)
            clean.save(output, format="JPEG", quality=82)
            return output.getvalue()
    except (Base64Error, ValueError, OSError, UnidentifiedImageError, Image.DecompressionBombError):
        raise HTTPException(
            422, "Choose a JPEG, PNG, or WebP profile photo under 256 KB."
        ) from None


def photo_response(photo: ProfilePhoto | None) -> str | None:
    return b64encode(photo.jpeg).decode("ascii") if photo else None


@router.get("/users/me/shared-photo", response_model=PhotoResponse)
def get_shared_photo(user: CurrentUser, session: DatabaseSession):
    try:
        return PhotoResponse(photo=photo_response(session.get(ProfilePhoto, user.id)))
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Profile photos are temporarily unavailable.") from None


@router.put("/users/me/shared-photo", response_model=PhotoResponse)
def share_photo(data: PhotoUpload, user: CurrentUser, session: DatabaseSession):
    jpeg = normalized_jpeg(data.photo)
    statement = insert(ProfilePhoto).values(user_id=user.id, jpeg=jpeg)
    try:
        session.execute(
            statement.on_conflict_do_update(
                index_elements=[ProfilePhoto.user_id], set_={"jpeg": statement.excluded.jpeg}
            )
        )
        session.commit()
        return PhotoResponse(photo=b64encode(jpeg).decode("ascii"))
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Profile photos are temporarily unavailable.") from None


@router.delete("/users/me/shared-photo", status_code=204, response_class=Response)
def unshare_photo(user: CurrentUser, session: DatabaseSession):
    try:
        session.execute(delete(ProfilePhoto).where(ProfilePhoto.user_id == user.id))
        session.commit()
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Profile photos are temporarily unavailable.") from None


@router.get("/requests/{request_id}/members/{member_id}", response_model=MemberCard)
def get_member_card(request_id: UUID, member_id: UUID, user: CurrentUser, session: DatabaseSession):
    try:
        request = session.get(HelpRequest, request_id)
        if request is None:
            raise HTTPException(404, "Member card unavailable.")
        if user.id == request.requester_id:
            helper_id = member_id
            statuses = ("pending", "accepted") if request.status == "active" else ("accepted",)
        elif member_id == request.requester_id:
            helper_id = user.id
            statuses = ("accepted",)
        else:
            raise HTTPException(404, "Member card unavailable.")
        allowed = session.scalar(
            select(Offer.id)
            .where(
                Offer.request_id == request_id,
                Offer.helper_id == helper_id,
                Offer.status.in_(statuses),
            )
            .limit(1)
        )
        member = session.get(User, member_id) if allowed else None
        if member is None or member.status != "active":
            raise HTTPException(404, "Member card unavailable.")
        count = session.scalar(completed_help_query(member_id))
        return MemberCard(
            display_name=member.display_name,
            completed_help_count=count,
            badges=[
                badge.label for badge in VOLUNTEER_MILESTONES if badge.required_completions <= count
            ],
            photo=photo_response(session.get(ProfilePhoto, member_id)),
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Member cards are temporarily unavailable.") from None
