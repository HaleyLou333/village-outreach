"""Offers serialize on the request lock shared with closure and messaging."""

import hashlib
import json
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import HelpRequest, Offer
from app.schemas.offers import OfferCreate, OfferResponse


def payload_hash(data) -> str:
    return hashlib.sha256(
        json.dumps(
            data.model_dump(mode="json"), sort_keys=True, separators=(",", ":"), ensure_ascii=True
        ).encode()
    ).hexdigest()


def locked_request(session: Session, request_id: UUID) -> HelpRequest:
    row = session.scalar(
        select(HelpRequest)
        .where(HelpRequest.id == request_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if row is None:
        raise HTTPException(404, "Request not found.")
    return row


def accepted_offer(session: Session, request_id: UUID) -> Offer | None:
    return session.scalar(
        select(Offer)
        .where(Offer.request_id == request_id, Offer.status == "accepted")
        .execution_options(populate_existing=True)
    )


def create_offer(
    session: Session, helper_id: UUID, data: OfferCreate, key: str
) -> tuple[OfferResponse, bool]:
    request = locked_request(session, data.request_id)
    if request.requester_id == helper_id:
        raise HTTPException(403, "Cannot offer on your own request.")
    digest = payload_hash(data)
    previous = session.scalar(
        select(Offer).where(Offer.helper_id == helper_id, Offer.idempotency_key == key)
    )
    if previous is not None:
        if previous.creation_hash != digest:
            raise HTTPException(409, "Idempotency key was used for different data.")
        return OfferResponse.model_validate(previous), False
    if request.status != "active" or accepted_offer(session, request.id) is not None:
        raise HTTPException(409, "Request is closed or already has an accepted helper.")
    inserted = session.scalar(
        insert(Offer)
        .values(
            request_id=request.id,
            helper_id=helper_id,
            message=data.message,
            idempotency_key=key,
            creation_hash=digest,
        )
        .on_conflict_do_nothing()
        .returning(Offer.id)
    )
    if inserted is None:
        previous = session.scalar(
            select(Offer).where(Offer.helper_id == helper_id, Offer.idempotency_key == key)
        )
        if previous is not None and previous.creation_hash == digest:
            return OfferResponse.model_validate(previous), False
        raise HTTPException(409, "Duplicate pending offer or reused idempotency key.")
    result = OfferResponse.model_validate(session.get(Offer, inserted))
    session.commit()
    return result, True


def list_offers(
    session: Session, request_id: UUID, user_id: UUID, limit: int, offset: int
) -> list[OfferResponse]:
    request = session.get(HelpRequest, request_id)
    if request is None:
        raise HTTPException(404, "Request not found.")
    query = select(Offer).where(Offer.request_id == request_id)
    if user_id != request.requester_id:
        query = query.where(Offer.helper_id == user_id)
    return [
        OfferResponse.model_validate(row)
        for row in session.scalars(
            query.order_by(Offer.created_at, Offer.id).limit(limit).offset(offset)
        )
    ]


def accept_offer(session: Session, offer_id: UUID, owner_id: UUID) -> OfferResponse:
    request_id = session.scalar(select(Offer.request_id).where(Offer.id == offer_id))
    if request_id is None:
        raise HTTPException(404, "Offer not found.")
    request = locked_request(session, request_id)
    if request.requester_id != owner_id:
        raise HTTPException(403, "Only the request owner may accept an offer.")
    row = session.scalar(
        select(Offer)
        .where(Offer.id == offer_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if request.status != "active":
        raise HTTPException(409, "Request is closed.")
    if row.status == "accepted":
        return OfferResponse.model_validate(row)
    if row.status != "pending" or accepted_offer(session, request_id) is not None:
        raise HTTPException(409, "Offer is no longer available.")
    session.execute(
        update(Offer)
        .where(Offer.request_id == request_id, Offer.status == "pending", Offer.id != offer_id)
        .values(status="declined")
    )
    row.status = "accepted"
    session.flush()
    result = OfferResponse.model_validate(row)
    session.commit()
    return result
