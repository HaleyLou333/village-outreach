"""Resolve a verified Auth subject to one private application profile."""

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.auth.tokens import VerifiedIdentity
from app.models import User


def resolve_user(session: Session, identity: VerifiedIdentity) -> User:
    user = session.scalar(select(User).where(User.supabase_uid == identity.subject))
    if user is not None:
        return user
    # The unique subject constraint arbitrates simultaneous first requests.
    # DO NOTHING preserves existing server-controlled fields in the losing request.
    session.execute(
        insert(User)
        .values(
            supabase_uid=identity.subject,
            email=identity.email,
            display_name=identity.display_name,
        )
        .on_conflict_do_nothing(index_elements=[User.supabase_uid])
    )
    session.commit()
    return session.scalars(select(User).where(User.supabase_uid == identity.subject)).one()
