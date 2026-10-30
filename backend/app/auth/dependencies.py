"""FastAPI dependencies shared by protected profile and request routes."""

from functools import lru_cache
from typing import Annotated

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.profiles import resolve_user
from app.auth.tokens import (
    AuthenticationUnavailable,
    InvalidToken,
    TokenVerifier,
    VerifiedIdentity,
)
from app.core.config import get_settings
from app.database.session import get_session
from app.models import User

bearer = HTTPBearer(auto_error=False)


@lru_cache
def get_token_verifier() -> TokenVerifier:
    return TokenVerifier(get_settings())


def get_verified_identity(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> VerifiedIdentity:
    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing access token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        return get_token_verifier().verify(credentials.credentials)
    except InvalidToken:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing access token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from None
    except AuthenticationUnavailable:
        raise HTTPException(
            status_code=503, detail="Authentication is temporarily unavailable."
        ) from None


def get_current_user(
    identity: Annotated[VerifiedIdentity, Depends(get_verified_identity)],
    session: Annotated[Session, Depends(get_session)],
) -> User:
    user = resolve_user(session, identity)
    if user.status != "active":
        raise HTTPException(status_code=403, detail="Account is not active.")
    return user
