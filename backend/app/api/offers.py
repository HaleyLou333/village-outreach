"""Authenticated offer creation, participant views and owner acceptance."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy.exc import SQLAlchemyError

from app.api.requests import CurrentUser, DatabaseSession, OperationKey
from app.schemas.offers import OfferCreate, OfferResponse
from app.schemas.requests import RequestError
from app.services.offers import accept_offer, create_offer, list_offers

router = APIRouter(
    tags=["Offers"],
    responses={code: {"model": RequestError} for code in [401, 403, 404, 409, 422, 503]},
)


def storage_failure(session) -> HTTPException:
    session.rollback()
    return HTTPException(503, "Offers are temporarily unavailable.")


@router.post(
    "/offers",
    response_model=OfferResponse,
    status_code=201,
    responses={200: {"model": OfferResponse, "description": "Exact creation retry"}},
)
def post_offer(
    data: OfferCreate,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
    idempotency_key: OperationKey,
):
    try:
        result, created = create_offer(session, user.id, data, idempotency_key)
        response.status_code = 201 if created else 200
        return result
    except SQLAlchemyError:
        raise storage_failure(session) from None


@router.get("/requests/{request_id}/offers", response_model=list[OfferResponse])
def get_offers(
    request_id: UUID,
    user: CurrentUser,
    session: DatabaseSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0, le=10000)] = 0,
):
    try:
        return list_offers(session, request_id, user.id, limit, offset)
    except SQLAlchemyError:
        raise storage_failure(session) from None


@router.post("/offers/{offer_id}/accept", response_model=OfferResponse)
def post_accept(offer_id: UUID, user: CurrentUser, session: DatabaseSession):
    try:
        return accept_offer(session, offer_id, user.id)
    except SQLAlchemyError:
        raise storage_failure(session) from None
