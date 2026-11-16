"""Organization membership management."""

from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Organization, OrganizationMember


def create_organization(
        session: Session,
        owner_id,
        name: str,
) -> Organization:
    organization = Organization(name=name)

    session.add(organization)
    session.flush()

    owner = OrganizationMember(
        user_id=owner_id,
        organization_id=organization.id,
        role="admin",
        approval_status="approved",
    )

    session.add(owner)
    session.commit()
    session.refresh(organization)

    return organization


def request_membership(
        session: Session,
        user_id,
        organization_id,
) -> OrganizationMember:
    existing = (
        session.query(OrganizationMember)
        .filter(
            OrganizationMember.user_id == user_id,
            OrganizationMember.organization_id == organization_id,
            )
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=409,
            detail="Membership already exists.",
        )

    membership = OrganizationMember(
        user_id=user_id,
        organization_id=organization_id,
        role="member",
        approval_status="pending",
    )

    session.add(membership)
    session.commit()
    session.refresh(membership)

    return membership


def require_approved_membership(
        session: Session,
        user_id: UUID,
        organization_id: UUID,
) -> OrganizationMember:
    membership = session.scalar(
        select(OrganizationMember).where(
            OrganizationMember.user_id == user_id,
            OrganizationMember.organization_id == organization_id,
            )
    )

    if membership is None:
        raise HTTPException(
            status_code=403,
            detail="Organization membership is required.",
        )

    if membership.approval_status != "approved":
        raise HTTPException(
            status_code=403,
            detail="Organization membership is not approved.",
        )

    return membership