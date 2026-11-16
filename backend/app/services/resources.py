"""Read only current, enabled service locations."""

from datetime import UTC, datetime, timedelta
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Resource
from app.schemas.resources import (
    ResourceCreate,
    ResourceQuery,
    ResourceUpdate,
)
from app.services.organizations import require_approved_membership
from app.services.requests import great_circle_distance

RESOURCE_VERIFICATION_MAX_AGE = timedelta(days=180)


def visible_resources():
    now = datetime.now(UTC)
    return select(Resource).where(
        Resource.is_active.is_(True),
        Resource.last_verified_at.between(
            now - RESOURCE_VERIFICATION_MAX_AGE,
            now,
            ),
    )


def list_resources(session: Session, filters: ResourceQuery) -> list[Resource]:
    query = visible_resources()

    if filters.area is not None:
        query = query.where(
            func.lower(Resource.area) == func.lower(filters.area)
        )

    if filters.category is not None:
        query = query.where(
            Resource.category == filters.category
        )

    if filters.latitude is not None and filters.longitude is not None:
        distance = great_circle_distance(
            Resource.latitude,
            Resource.longitude,
            filters.latitude,
            filters.longitude,
        )

        query = query.where(
            distance <= (filters.radius_km or 10)
        ).order_by(distance)

    return list(
        session.scalars(
            query.order_by(
                Resource.name,
                Resource.id,
            )
            .limit(filters.limit)
            .offset(filters.offset)
        )
    )


def resource_detail(
        session: Session,
        resource_id: UUID,
) -> Resource:
    row = session.scalar(
        visible_resources().where(
            Resource.id == resource_id
        )
    )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Resource not found.",
        )

    return row


def create_resource(
        session: Session,
        user_id: UUID,
        data: ResourceCreate,
) -> Resource:
    require_approved_membership(
        session,
        user_id,
        data.organization_id,
    )

    resource = Resource(
        **data.model_dump(),
        is_active=True,
        last_verified_at=datetime.now(UTC),
    )

    session.add(resource)

    session.flush()
    session.refresh(resource)

    session.commit()

    return resource


def update_resource(
        session: Session,
        resource_id: UUID,
        user_id: UUID,
        data: ResourceUpdate,
) -> Resource:
    resource = session.get(
        Resource,
        resource_id,
        with_for_update=True,
    )

    if resource is None:
        raise HTTPException(
            status_code=404,
            detail="Resource not found.",
        )

    if resource.organization_id is None:
        raise HTTPException(
            status_code=409,
            detail="Resource is not organization managed.",
        )

    require_approved_membership(
        session,
        user_id,
        resource.organization_id,
    )

    changes = data.model_dump(
        exclude_unset=True,
    )

    for field, value in changes.items():
        setattr(resource, field, value)

    session.flush()
    session.refresh(resource)

    session.commit()

    return resource


def disable_resource(
        session: Session,
        resource_id: UUID,
        user_id: UUID,
) -> Resource:
    resource = session.get(
        Resource,
        resource_id,
        with_for_update=True,
    )

    if resource is None:
        raise HTTPException(
            status_code=404,
            detail="Resource not found.",
        )

    if resource.organization_id is None:
        raise HTTPException(
            status_code=409,
            detail="Resource is not organization managed.",
        )

    require_approved_membership(
        session,
        user_id,
        resource.organization_id,
    )

    resource.is_active = False

    session.flush()
    session.refresh(resource)

    session.commit()

    return resource