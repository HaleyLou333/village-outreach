"""Disposable signing fixtures shared by authentication integration tests."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.config import Settings

ISSUER = "https://example.supabase.co/auth/v1"


@pytest.fixture
def signing_key():
    return ec.generate_private_key(ec.SECP256R1())


@pytest.fixture
def claims():
    now = datetime.now(UTC)
    return {
        "iss": ISSUER,
        "aud": "authenticated",
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "iat": int(now.timestamp()),
        "sub": str(uuid4()),
        "role": "authenticated",
        "email": "neighbor@example.com",
        "is_anonymous": False,
        "user_metadata": {"display_name": "Neighbor", "role": "admin"},
    }


@pytest.fixture
def verifier(monkeypatch, signing_key):
    from app.auth.tokens import TokenVerifier

    jwk = jwt.algorithms.ECAlgorithm.to_jwk(signing_key.public_key(), as_dict=True)
    jwk.update(kid="test-key", use="sig", alg="ES256")
    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", lambda self: {"keys": [jwk]})
    return TokenVerifier(Settings(_env_file=None, supabase_url="https://example.supabase.co"))


def encode(claims, signing_key):
    return jwt.encode(claims, signing_key, algorithm="ES256", headers={"kid": "test-key"})
