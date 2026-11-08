"""Private requester/accepted-helper conversations, including closed history."""

from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import HelpRequest, Message
from app.schemas.messages import MessageCreate, MessageResponse
from app.services.offers import accepted_offer, locked_request, payload_hash


def other_participant(session: Session, request: HelpRequest, user_id: UUID) -> UUID:
    offer = accepted_offer(session, request.id)
    if offer is None or user_id not in (request.requester_id, offer.helper_id):
        raise HTTPException(403, "Conversation is restricted to the requester and accepted helper.")
    return offer.helper_id if user_id == request.requester_id else request.requester_id


def create_message(
    session: Session, sender_id: UUID, data: MessageCreate, key: str
) -> tuple[MessageResponse, bool]:
    request = locked_request(session, data.request_id)
    receiver = other_participant(session, request, sender_id)
    if receiver != data.receiver_id:
        raise HTTPException(403, "Receiver must be the other conversation participant.")
    digest = payload_hash(data)
    previous = session.scalar(
        select(Message).where(Message.sender_id == sender_id, Message.idempotency_key == key)
    )
    if previous is not None:
        if previous.creation_hash != digest:
            raise HTTPException(409, "Idempotency key was used for different data.")
        return MessageResponse.model_validate(previous), False
    if request.status != "active":
        raise HTTPException(409, "New messages are not allowed on closed requests.")
    inserted = session.scalar(
        insert(Message)
        .values(**data.model_dump(), sender_id=sender_id, idempotency_key=key, creation_hash=digest)
        .on_conflict_do_nothing()
        .returning(Message.id)
    )
    if inserted is None:
        previous = session.scalar(
            select(Message).where(Message.sender_id == sender_id, Message.idempotency_key == key)
        )
        if previous is not None and previous.creation_hash == digest:
            return MessageResponse.model_validate(previous), False
        raise HTTPException(409, "Idempotency key was used for different data.")
    result = MessageResponse.model_validate(session.get(Message, inserted))
    session.commit()
    return result, True


def list_messages(
    session: Session, request_id: UUID, user_id: UUID, limit: int, offset: int
) -> list[MessageResponse]:
    request = session.get(HelpRequest, request_id)
    if request is None:
        raise HTTPException(404, "Request not found.")
    other_participant(session, request, user_id)
    return [
        MessageResponse.model_validate(row)
        for row in session.scalars(
            select(Message)
            .where(Message.request_id == request_id)
            .order_by(Message.created_at, Message.id)
            .limit(limit)
            .offset(offset)
        )
    ]
