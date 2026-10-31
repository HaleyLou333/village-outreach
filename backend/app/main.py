import logging
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exception_handlers import http_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.profiles import router as profile_router
from app.api.requests import router as request_router

app = FastAPI(title="CCVO Backend", version="0.1.0")
app.include_router(profile_router)
app.include_router(request_router)
logger = logging.getLogger("app.http")


@app.middleware("http")
async def request_context(request: Request, call_next):
    request_id = str(uuid4())
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    if request.url.path.startswith(("/requests", "/users")):
        response.headers["Cache-Control"] = "no-store"
    logger.info(
        "request_id=%s method=%s path=%s status=%s",
        request_id,
        request.method,
        request.url.path,
        response.status_code,
    )
    return response


@app.exception_handler(StarletteHTTPException)
async def request_error(request: Request, error: StarletteHTTPException):
    if request.url.path == "/requests" or request.url.path.startswith("/requests/"):
        codes = {
            401: "unauthenticated",
            403: "forbidden",
            404: "not_found",
            409: "conflict",
            422: "invalid_request",
            503: "service_unavailable",
        }
        return JSONResponse(
            status_code=error.status_code,
            content={"detail": error.detail, "code": codes.get(error.status_code, "request_error")},
            headers=error.headers,
        )
    return await http_exception_handler(request, error)


@app.exception_handler(RequestValidationError)
def invalid_request(request: Request, error: RequestValidationError) -> JSONResponse:
    # Do not reflect arbitrary profile data (including malformed Unicode) in errors.
    content = {"detail": "Invalid request data."}
    if request.url.path == "/requests" or request.url.path.startswith("/requests/"):
        content.update(
            code="invalid_request",
            fields=[{"loc": list(item["loc"]), "type": item["type"]} for item in error.errors()],
        )
    return JSONResponse(status_code=422, content=content)


@app.get("/health")
def health_check():
    return {"status": "ok"}
