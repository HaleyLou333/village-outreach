"""Submission-only safety reports."""

from fastapi import APIRouter, HTTPException, Response
from sqlalchemy.exc import SQLAlchemyError

from app.api.requests import CurrentUser, DatabaseSession, OperationKey
from app.schemas.reports import ReportCreate, ReportReceipt
from app.schemas.requests import RequestError
from app.services.reports import submit_report

router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
    responses={code: {"model": RequestError} for code in (401, 403, 404, 409, 422, 503)},
)


@router.post(
    "",
    response_model=ReportReceipt,
    status_code=201,
    responses={200: {"model": ReportReceipt, "description": "Exact submission retry"}},
)
def post_report(
    data: ReportCreate,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
    idempotency_key: OperationKey,
) -> ReportReceipt:
    try:
        report_id, created = submit_report(session, user.id, data, idempotency_key)
    except SQLAlchemyError:
        session.rollback()
        raise HTTPException(503, "Reporting is temporarily unavailable.") from None
    response.status_code = 201 if created else 200
    return ReportReceipt(id=report_id)
