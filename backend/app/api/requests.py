"""Authenticated request creation, nearby browsing, and owner updates."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database.session import get_session
from app.models import User
from app.schemas.requests import (
    FeedRequestResponse,
    Latitude,
    Longitude,
    RequestCreate,
    RequestError,
    RequestResponse,
    RequestUpdate,
)
from app.services.requests import create_request, request_detail, request_feed, update_request

router = APIRouter(
    prefix="/requests",
    tags=["Requests"],
    responses={
        401: {"model": RequestError, "description": "Missing or invalid access token"},
        403: {"model": RequestError, "description": "Inactive account or forbidden owner action"},
        404: {"model": RequestError, "description": "Request not found"},
        409: {"model": RequestError, "description": "Idempotency or request status conflict"},
        422: {"model": RequestError, "description": "Invalid request data"},
        503: {"model": RequestError, "description": "Authentication or storage unavailable"},
    },
)
CurrentUser = Annotated[User, Depends(get_current_user)]
DatabaseSession = Annotated[Session, Depends(get_session)]
OperationKey = Annotated[str, Header(alias="Idempotency-Key", pattern=r"^[A-Za-z0-9._:-]{8,128}$")]


def storage_failure(session: Session) -> HTTPException:
    session.rollback()
    return HTTPException(status_code=503, detail="Requests are temporarily unavailable.")


@router.post(
    "",
    response_model=RequestResponse,
    status_code=201,
    responses={200: {"model": RequestResponse, "description": "Exact creation retry"}},
)
def post_request(
    data: RequestCreate,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
    idempotency_key: OperationKey,
) -> RequestResponse:
    try:
        result, created = create_request(session, user.id, data, idempotency_key)
    except SQLAlchemyError:
        raise storage_failure(session) from None
    response.status_code = 201 if created else 200
    return result


@router.get("", response_model=list[FeedRequestResponse])
def get_requests(
    user: CurrentUser,
    session: DatabaseSession,
    latitude: Latitude,
    longitude: Longitude,
    radius_km: Annotated[float, Query(gt=0, le=100, allow_inf_nan=False)] = 10,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
) -> list[FeedRequestResponse]:
    try:
        return request_feed(session, latitude, longitude, radius_km, limit, offset)
    except SQLAlchemyError:
        raise storage_failure(session) from None


@router.get("/{request_id}", response_model=RequestResponse)
def get_request(request_id: UUID, user: CurrentUser, session: DatabaseSession) -> RequestResponse:
    try:
        return request_detail(session, request_id)
    except SQLAlchemyError:
        raise storage_failure(session) from None


@router.patch("/{request_id}", response_model=RequestResponse)
def patch_request(
    request_id: UUID, data: RequestUpdate, user: CurrentUser, session: DatabaseSession
) -> RequestResponse:
    try:
        return update_request(session, request_id, user.id, data)
    except SQLAlchemyError:
        raise storage_failure(session) from None
