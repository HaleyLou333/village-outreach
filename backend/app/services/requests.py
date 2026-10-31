"""Persistence and distance operations for requests."""

import hashlib
import json
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import Float, Numeric, Text, cast, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import HelpRequest
from app.schemas.requests import FeedRequestResponse, RequestCreate, RequestResponse, RequestUpdate

EARTH_RADIUS_KM = 6371.0088


def public_coordinate(value: float) -> float:
    return float(Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def public_request(row: HelpRequest) -> RequestResponse:
    value = RequestResponse.model_validate(row)
    return value.model_copy(
        update={
            "latitude": public_coordinate(row.latitude),
            "longitude": public_coordinate(row.longitude),
        }
    )


def create_request(
    session: Session, requester_id: UUID, data: RequestCreate, key: str
) -> tuple[RequestResponse, bool]:
    payload = data.model_dump(mode="json")
    # The immutable digest describes normalized creation input, not later edits.
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode(
            "utf-8"
        )
    ).hexdigest()
    inserted_id = session.scalar(
        insert(HelpRequest)
        .values(**payload, requester_id=requester_id, idempotency_key=key, creation_hash=digest)
        .on_conflict_do_nothing(
            index_elements=[HelpRequest.requester_id, HelpRequest.idempotency_key]
        )
        .returning(HelpRequest.id)
    )
    if inserted_id is None:
        row = session.scalar(
            select(HelpRequest)
            .where(HelpRequest.requester_id == requester_id, HelpRequest.idempotency_key == key)
            .execution_options(populate_existing=True)
        )
        if row is None:
            raise HTTPException(status_code=503, detail="Requests are temporarily unavailable.")
        if row.creation_hash != digest:
            raise HTTPException(
                status_code=409, detail="Idempotency key was used for different data."
            )
        return public_request(row), False
    row = session.get(HelpRequest, inserted_id)
    result = public_request(row)
    session.commit()
    return result, True


def distance_expression(latitude: float, longitude: float):
    """Distance uses only public cells, preventing raw-location radius probes."""
    # Text preserves PostgreSQL's shortest float representation; direct float ->
    # numeric truncates to 15 digits and can move values just below a half tie.
    # Numeric round and Decimal ROUND_HALF_UP both round ties away from zero.
    public_lat = cast(func.round(cast(cast(HelpRequest.latitude, Text), Numeric), 2), Float)
    public_lon = cast(func.round(cast(cast(HelpRequest.longitude, Text), Numeric), 2), Float)
    lat_delta = func.radians(public_lat - latitude)
    lon_delta = func.radians(public_lon - longitude)
    haversine = func.power(func.sin(lat_delta / 2), 2) + func.cos(
        func.radians(latitude)
    ) * func.cos(func.radians(public_lat)) * func.power(func.sin(lon_delta / 2), 2)
    return (
        2 * EARTH_RADIUS_KM * func.asin(func.sqrt(func.least(1.0, func.greatest(0.0, haversine))))
    )


def request_feed(
    session: Session, latitude: float, longitude: float, radius_km: float, limit: int, offset: int
) -> list[FeedRequestResponse]:
    distance = distance_expression(latitude, longitude).label("distance_km")
    rows = session.execute(
        select(HelpRequest, distance)
        .where(HelpRequest.status == "active", distance <= radius_km)
        .order_by(distance.asc(), HelpRequest.created_at.desc(), HelpRequest.id.asc())
        .limit(limit)
        .offset(offset)
    )
    return [
        FeedRequestResponse(**public_request(row).model_dump(), distance_km=round(km, 1))
        for row, km in rows
    ]


def request_detail(session: Session, request_id: UUID) -> RequestResponse:
    row = session.get(HelpRequest, request_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Request not found.")
    return public_request(row)


def update_request(
    session: Session, request_id: UUID, requester_id: UUID, data: RequestUpdate
) -> RequestResponse:
    row = session.get(HelpRequest, request_id, with_for_update=True, populate_existing=True)
    if row is None:
        raise HTTPException(status_code=404, detail="Request not found.")
    if row.requester_id != requester_id:
        raise HTTPException(status_code=403, detail="Only the owner can update this request.")
    changes = data.model_dump(exclude_unset=True)
    if row.status != "active":
        if changes == {"status": row.status}:
            return public_request(row)
        raise HTTPException(status_code=409, detail="Closed requests cannot be changed.")
    for field, value in changes.items():
        setattr(row, field, value)
    session.flush()
    session.refresh(row)
    # Capture the locked version before commit expires attributes/releases the lock.
    result = public_request(row)
    session.commit()
    return result
