"""Read only current, enabled service locations."""

from datetime import UTC, datetime, timedelta
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Resource
from app.schemas.resources import ResourceQuery
from app.services.requests import great_circle_distance

RESOURCE_VERIFICATION_MAX_AGE = timedelta(days=180)


def visible_resources():
    now = datetime.now(UTC)
    return select(Resource).where(
        Resource.is_active.is_(True),
        Resource.last_verified_at.between(now - RESOURCE_VERIFICATION_MAX_AGE, now),
    )


def list_resources(session: Session, filters: ResourceQuery) -> list[Resource]:
    query = visible_resources()
    if filters.area is not None:
        query = query.where(func.lower(Resource.area) == func.lower(filters.area))
    if filters.category is not None:
        query = query.where(Resource.category == filters.category)
    if filters.latitude is not None and filters.longitude is not None:
        distance = great_circle_distance(
            Resource.latitude, Resource.longitude, filters.latitude, filters.longitude
        )
        query = query.where(distance <= (filters.radius_km or 10)).order_by(distance)
    return list(
        session.scalars(
            query.order_by(Resource.name, Resource.id).limit(filters.limit).offset(filters.offset)
        )
    )


def resource_detail(session: Session, resource_id: UUID) -> Resource:
    row = session.scalar(visible_resources().where(Resource.id == resource_id))
    if row is None:
        raise HTTPException(404, "Resource not found.")
    return row
