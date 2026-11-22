"""Verified resource recommendation logic."""

from sqlalchemy.orm import Session

from app.models import Resource
from app.schemas.resources import ResourceQuery
from app.services.resources import list_resources


def recommend_resources(
        session: Session,
        filters: ResourceQuery,
) -> list[Resource]:
    """Return verified, active resources for a validated category."""

    return list_resources(
        session=session,
        filters=filters,
    )