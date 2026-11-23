"""Authenticated browsing of published local resource guides."""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError

from app.api.requests import CurrentUser, DatabaseSession
from app.models import ResourceGuide
from app.schemas.requests import Area
from app.schemas.resources import ResourceCategory

router = APIRouter(prefix="/resource-guides", tags=["Resource Guides"])


class GuideQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category: ResourceCategory | None = None
    area: Area | None = None
    limit: Annotated[int, Field(ge=1, le=100)] = 20
    offset: Annotated[int, Field(ge=0, le=10000)] = 0


class GuideSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    category: str
    area: str
    source_url: str
    reviewed_at: datetime


class GuideDetail(GuideSummary):
    body: str


@router.get("", response_model=list[GuideSummary])
def list_guides(
    user: CurrentUser, session: DatabaseSession, filters: Annotated[GuideQuery, Query()]
):
    """Browse published guides, newest source review first."""
    query = select(ResourceGuide).where(ResourceGuide.published)
    if filters.category is not None:
        query = query.where(ResourceGuide.category == filters.category)
    if filters.area is not None:
        query = query.where(func.lower(ResourceGuide.area) == filters.area.lower())
    try:
        return session.scalars(
            query.order_by(ResourceGuide.reviewed_at.desc(), ResourceGuide.id.desc())
            .limit(filters.limit)
            .offset(filters.offset)
        ).all()
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Resource guides are temporarily unavailable.") from None


@router.get("/{guide_id}", response_model=GuideDetail)
def get_guide(guide_id: UUID, user: CurrentUser, session: DatabaseSession):
    """Open a published guide and its source and review metadata."""
    try:
        guide = session.scalar(
            select(ResourceGuide).where(ResourceGuide.id == guide_id, ResourceGuide.published)
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Resource guides are temporarily unavailable.") from None
    if guide is None:
        raise HTTPException(404, "Resource guide not found.")
    return guide
