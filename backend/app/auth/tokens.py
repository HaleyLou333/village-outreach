"""Verify access tokens before using any identity or profile claims."""

from dataclasses import dataclass
from uuid import UUID

import jwt

from app.core.config import Settings


class InvalidToken(Exception):
    """Credentials do not represent an accepted signed-in identity."""


class AuthenticationUnavailable(Exception):
    """Authentication is unconfigured or its key service is unavailable."""


class ProjectKeyClient(jwt.PyJWKClient):
    def get_signing_keys(self, refresh: bool = False) -> list[jwt.PyJWK]:
        try:
            return super().get_signing_keys(refresh=refresh)
        except (jwt.PyJWTError, ValueError, TypeError, KeyError):
            # An unusable key service is different from an unknown token kid.
            # The latter is raised by the parent get_signing_key, outside here.
            raise AuthenticationUnavailable from None


@dataclass(frozen=True)
class VerifiedIdentity:
    subject: UUID
    email: str
    display_name: str


class TokenVerifier:
    def __init__(self, settings: Settings):
        if settings.supabase_url is None:
            raise AuthenticationUnavailable
        self.issuer = settings.supabase_url + "/auth/v1"
        self.keys = ProjectKeyClient(
            self.issuer + "/.well-known/jwks.json",
            cache_keys=False,
            lifespan=300,
            timeout=5,
        )

    def verify(self, token: str) -> VerifiedIdentity:
        try:
            if not token or len(token) > 16384:
                raise InvalidToken
            header = jwt.get_unverified_header(token)
            # Header values select only among this fixed asymmetric allowlist.
            if header.get("alg") not in {"ES256", "RS256"} or not header.get("kid"):
                raise InvalidToken
            key = self.keys.get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token,
                key.key,
                algorithms=["ES256", "RS256"],
                issuer=self.issuer,
                audience="authenticated",
                options={"require": ["iss", "aud", "exp", "sub", "role", "email"]},
            )
            if claims["role"] != "authenticated" or claims.get("is_anonymous", False) is not False:
                raise InvalidToken
            subject = UUID(claims["sub"])
            email = claims["email"]
            if (
                not isinstance(email, str)
                or not 1 <= len(email.strip()) <= 254
                or "@" not in email
                or "\x00" in email
            ):
                raise InvalidToken
            metadata = claims.get("user_metadata")
            name = metadata.get("display_name") if isinstance(metadata, dict) else None
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100 or "\x00" in name:
                name = "Neighbor"
            return VerifiedIdentity(subject=subject, email=email.strip(), display_name=name.strip())
        except jwt.PyJWKClientConnectionError:
            raise AuthenticationUnavailable from None
        except (jwt.PyJWTError, ValueError, TypeError, KeyError):
            raise InvalidToken from None
