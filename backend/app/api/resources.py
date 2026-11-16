"""Authenticated resource browsing for map and list clients."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy.exc import SQLAlchemyError

from app.api.requests import CurrentUser, DatabaseSession
from app.schemas.requests import RequestError
from app.schemas.resources import (
    ResourceCreate,
    ResourceQuery,
    ResourceResponse,
    ResourceUpdate,
)
from app.services.resources import (
    create_resource,
    disable_resource,
    list_resources,
    resource_detail,
    update_resource,
)

router = APIRouter(
    prefix="/resources",
    tags=["Resources"],
    responses={code: {"model": RequestError} for code in (401, 403, 404, 422, 503)},
)


@router.get("", response_model=list[ResourceResponse])
def get_resources(
    user: CurrentUser, session: DatabaseSession, filters: Annotated[ResourceQuery, Query()]
):
    try:
        return list_resources(session, filters)
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Resources are temporarily unavailable.") from None


@router.get("/{resource_id}", response_model=ResourceResponse)
def get_resource(resource_id: UUID, user: CurrentUser, session: DatabaseSession):
    try:
        return resource_detail(session, resource_id)
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Resources are temporarily unavailable.") from None


@router.post("", response_model=ResourceResponse, status_code=201)
def post_resource(
        data: ResourceCreate,
        user: CurrentUser,
        session: DatabaseSession,
):
    try:
        return create_resource(
            session,
            user.id,
            data,
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(
            503,
            "Resources are temporarily unavailable.",
        ) from None


@router.patch("/{resource_id}", response_model=ResourceResponse)
def patch_resource(
        resource_id: UUID,
        data: ResourceUpdate,
        user: CurrentUser,
        session: DatabaseSession,
):
    try:
        return update_resource(
            session,
            resource_id,
            user.id,
            data,
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(
            503,
            "Resources are temporarily unavailable.",
        ) from None


@router.delete("/{resource_id}", response_model=ResourceResponse)
def delete_resource(
        resource_id: UUID,
        user: CurrentUser,
        session: DatabaseSession,
):
    try:
        return disable_resource(
            session,
            resource_id,
            user.id,
        )
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(
            503,
            "Resources are temporarily unavailable.",
        ) from None