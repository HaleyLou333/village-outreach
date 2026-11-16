"""Organization resource authorization checks."""

from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.models import Organization, OrganizationMember, User
from app.services.organizations import require_approved_membership

pytestmark = pytest.mark.database


def test_unapproved_membership_is_rejected(db_session):
    organization = Organization(name="Test Organization")
    db_session.add(organization)

    user = User(
        supabase_uid=uuid4(),
        email="pending@example.com",
        display_name="Pending User",
    )
    db_session.add(user)

    db_session.flush()

    membership = OrganizationMember(
        user_id=user.id,
        organization_id=organization.id,
        role="member",
        approval_status="pending",
    )

    db_session.add(membership)
    db_session.flush()

    with pytest.raises(HTTPException) as error:
        require_approved_membership(
            db_session,
            user.id,
            organization.id,
        )

    assert error.value.status_code == 403


def test_cross_organization_membership_is_rejected(db_session):
    organization_a = Organization(name="Organization A")
    organization_b = Organization(name="Organization B")

    db_session.add_all([organization_a, organization_b])
    db_session.flush()

    user = User(
        supabase_uid=uuid4(),
        email="approved@example.com",
        display_name="Approved User",
    )

    db_session.add(user)
    db_session.flush()

    user_id = user.id

    membership = OrganizationMember(
        user_id=user_id,
        organization_id=organization_a.id,
        role="member",
        approval_status="approved",
    )

    db_session.add(membership)
    db_session.flush()

    with pytest.raises(HTTPException) as error:
        require_approved_membership(
            db_session,
            user_id,
            organization_b.id,
        )

    assert error.value.status_code == 403