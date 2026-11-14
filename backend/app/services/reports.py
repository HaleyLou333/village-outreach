"""Validate report targets and store submissions without exposing moderation data."""

from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import HelpRequest, Report, User
from app.schemas.reports import ReportCreate
from app.services.offers import payload_hash


def submit_report(
    session: Session, reporter_id: UUID, data: ReportCreate, key: str
) -> tuple[UUID, bool]:
    digest = payload_hash(data)
    existing_query = select(Report.id, Report.creation_hash).where(
        Report.reporter_id == reporter_id, Report.idempotency_key == key
    )
    existing = session.execute(existing_query).one_or_none()
    if existing is not None:
        return report_retry(existing.id, existing.creation_hash, digest), False

    if data.target_type == "request":
        if session.get(HelpRequest, data.target_id) is None:
            raise HTTPException(404, "Report target not found.")
        target = {"request_id": data.target_id}
    else:
        if data.target_id == reporter_id:
            raise HTTPException(403, "You cannot report your own account.")
        if session.get(User, data.target_id) is None:
            raise HTTPException(404, "Report target not found.")
        target = {"reported_user_id": data.target_id}

    report_id = session.scalar(
        insert(Report)
        .values(
            **target,
            reporter_id=reporter_id,
            reason=data.reason,
            description=data.description,
            idempotency_key=key,
            creation_hash=digest,
        )
        .on_conflict_do_nothing(index_elements=[Report.reporter_id, Report.idempotency_key])
        .returning(Report.id)
    )
    if report_id is None:
        existing = session.execute(existing_query).one()
        return report_retry(existing.id, existing.creation_hash, digest), False
    session.commit()
    return report_id, True


def report_retry(report_id: UUID, previous_digest: str, digest: str) -> UUID:
    if previous_digest != digest:
        raise HTTPException(409, "Idempotency key was used for different data.")
    return report_id
