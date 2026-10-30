from typing import Annotated

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.auth.tokens import VerifiedIdentity
from app.core.config import Settings
from tests.auth_helpers import encode


def test_verified_identity_comes_from_signed_subject(verifier, claims, signing_key):
    identity = verifier.verify(encode(claims, signing_key))
    assert str(identity.subject) == claims["sub"]
    assert identity.email == "neighbor@example.com"
    assert identity.display_name == "Neighbor"
    assert not hasattr(identity, "role")


@pytest.mark.parametrize(
    "field,value",
    [
        ("iss", "https://attacker.example/auth/v1"),
        ("aud", "service_role"),
        ("exp", 1),
        ("iat", 9999999999),
        ("sub", "not-a-uuid"),
        ("role", "service_role"),
        ("is_anonymous", True),
        ("email", ""),
        ("email", "x" * 255),
        ("email", "bad\u0000@example.com"),
    ],
)
def test_invalid_claims_rejected(verifier, claims, signing_key, field, value):
    from app.auth.tokens import InvalidToken

    claims[field] = value
    with pytest.raises(InvalidToken):
        verifier.verify(encode(claims, signing_key))


@pytest.mark.parametrize("field", ["iss", "aud", "exp", "sub", "role", "email"])
def test_required_claims_rejected_when_missing(verifier, claims, signing_key, field):
    from app.auth.tokens import InvalidToken

    del claims[field]
    with pytest.raises(InvalidToken):
        verifier.verify(encode(claims, signing_key))


def test_forged_signature_rejected(verifier, claims):
    from app.auth.tokens import InvalidToken

    attacker_key = ec.generate_private_key(ec.SECP256R1())
    with pytest.raises(InvalidToken):
        verifier.verify(encode(claims, attacker_key))


def test_unknown_key_id_rejected(verifier, claims, signing_key):
    from app.auth.tokens import InvalidToken

    token = jwt.encode(claims, signing_key, algorithm="ES256", headers={"kid": "unknown"})
    with pytest.raises(InvalidToken):
        verifier.verify(token)


def test_rsa_project_key_supported(monkeypatch, claims):
    from cryptography.hazmat.primitives.asymmetric import rsa

    from app.auth.tokens import TokenVerifier

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    jwk = jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key(), as_dict=True)
    jwk.update(kid="rsa-key", use="sig", alg="RS256")
    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", lambda self: {"keys": [jwk]})
    verifier = TokenVerifier(Settings(_env_file=None, supabase_url="https://example.supabase.co"))
    token = jwt.encode(claims, key, algorithm="RS256", headers={"kid": "rsa-key"})
    assert str(verifier.verify(token).subject) == claims["sub"]


@pytest.mark.parametrize("token", ["garbage", "a.b.c", "", "x" * 20000])
def test_malformed_tokens_rejected(verifier, token):
    from app.auth.tokens import InvalidToken

    with pytest.raises(InvalidToken):
        verifier.verify(token)


def test_unsigned_and_symmetric_tokens_rejected(verifier, claims):
    from app.auth.tokens import InvalidToken

    for algorithm, key in [("none", ""), ("HS256", "x" * 32)]:
        with pytest.raises(InvalidToken):
            verifier.verify(jwt.encode(claims, key, algorithm=algorithm))


@pytest.mark.parametrize("name", ["x" * 101, "\u0000", "  ", 123, []])
def test_untrusted_display_name_falls_back(verifier, claims, signing_key, name):
    claims["user_metadata"] = {"display_name": name}
    assert verifier.verify(encode(claims, signing_key)).display_name == "Neighbor"


@pytest.fixture
def protected_client(verifier, monkeypatch):
    from app.auth import dependencies
    from app.auth.dependencies import get_verified_identity

    app = FastAPI()

    @app.get("/protected")
    def protected(identity: Annotated[VerifiedIdentity, Depends(get_verified_identity)]):
        return {"subject": str(identity.subject)}

    monkeypatch.setattr(dependencies, "get_token_verifier", lambda: verifier)
    with TestClient(app) as client:
        yield client


@pytest.mark.parametrize("header", [None, "Basic abc", "Bearer", "Bearer bad-token"])
def test_protected_access_rejects_bad_credentials(protected_client, header):
    headers = {} if header is None else {"Authorization": header}
    response = protected_client.get("/protected", headers=headers)
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json() == {"detail": "Invalid or missing access token."}


def test_protected_access_accepts_verified_token(protected_client, claims, signing_key):
    response = protected_client.get(
        "/protected", headers={"Authorization": "Bearer " + encode(claims, signing_key)}
    )
    assert response.status_code == 200
    assert response.json() == {"subject": claims["sub"]}


def test_jwks_outage_returns_generic_503(protected_client, monkeypatch, claims, signing_key):
    def unavailable(self):
        raise jwt.PyJWKClientConnectionError("sensitive upstream error")

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", unavailable)
    response = protected_client.get(
        "/protected", headers={"Authorization": "Bearer " + encode(claims, signing_key)}
    )
    assert response.status_code == 503
    assert "sensitive" not in response.text


@pytest.mark.parametrize("key_set", [{"keys": []}, {}, {"keys": [{"kty": "invalid"}]}])
def test_unusable_jwks_returns_503(protected_client, monkeypatch, claims, signing_key, key_set):
    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", lambda self: key_set)
    response = protected_client.get(
        "/protected", headers={"Authorization": "Bearer " + encode(claims, signing_key)}
    )
    assert response.status_code == 503


def test_invalid_jwks_json_returns_503(protected_client, monkeypatch, claims, signing_key):
    def broken_response(self):
        raise ValueError("invalid upstream JSON")

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", broken_response)
    response = protected_client.get(
        "/protected", headers={"Authorization": "Bearer " + encode(claims, signing_key)}
    )
    assert response.status_code == 503


def test_missing_configuration_does_not_enable_access():
    from app.auth.tokens import AuthenticationUnavailable, TokenVerifier

    with pytest.raises(AuthenticationUnavailable):
        TokenVerifier(Settings(_env_file=None))


@pytest.mark.parametrize(
    "url", ["http://example.com", "https://user:secret@example.com", "https://example.com/path"]
)
def test_unsafe_project_url_rejected(url):
    with pytest.raises(ValueError):
        Settings(_env_file=None, supabase_url=url)
