"""Participant-authorized private message send and history routes."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy.exc import SQLAlchemyError

from app.api.requests import CurrentUser, DatabaseSession, OperationKey
from app.schemas.messages import MessageCreate, MessageResponse
from app.schemas.requests import RequestError
from app.services.messages import create_message, list_messages

router = APIRouter(
    tags=["Messages"],
    responses={code: {"model": RequestError} for code in [401, 403, 404, 409, 422, 503]},
)


def storage_failure(session) -> HTTPException:
    session.rollback()
    return HTTPException(503, "Messages are temporarily unavailable.")


@router.post(
    "/messages",
    response_model=MessageResponse,
    status_code=201,
    responses={200: {"model": MessageResponse, "description": "Exact send retry"}},
)
def post_message(
    data: MessageCreate,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
    idempotency_key: OperationKey,
):
    try:
        result, created = create_message(session, user.id, data, idempotency_key)
        response.status_code = 201 if created else 200
        return result
    except SQLAlchemyError:
        raise storage_failure(session) from None


@router.get("/requests/{request_id}/messages", response_model=list[MessageResponse])
def get_messages(
    request_id: UUID,
    user: CurrentUser,
    session: DatabaseSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
):
    try:
        return list_messages(session, request_id, user.id, limit, offset)
    except SQLAlchemyError:
        raise storage_failure(session) from None
