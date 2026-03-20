"""FastAPI dependency for Supabase JWT authentication."""

import os
import logging
from functools import lru_cache

import httpx
import jwt
from jwt import PyJWKClient
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer()


@lru_cache()
def _get_jwks_client() -> PyJWKClient:
    """Build a cached JWKS client for the Supabase project."""
    supabase_url = os.getenv("SUPABASE_URL", "")
    jwks_url = f"{supabase_url}/auth/v1/.well-known/jwks.json"
    return PyJWKClient(jwks_url)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> str:
    """Extract and verify user_id from Supabase JWT.

    Supports both legacy HS256 (shared secret) and new ES256 (JWKS) tokens.
    Returns the user's UUID string.
    Raises 401 if token is missing, invalid, or expired.
    """
    token = credentials.credentials

    # Peek at the token header to determine algorithm
    try:
        header = jwt.get_unverified_header(token)
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token header",
        )

    try:
        if header.get("alg") == "HS256":
            # Legacy: verify with shared secret
            jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
            if not jwt_secret:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="SUPABASE_JWT_SECRET not configured",
                )
            payload = jwt.decode(
                token,
                jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
            )
        else:
            # New ECC/RSA: verify with JWKS
            jwks_client = _get_jwks_client()
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256"],
                audience="authenticated",
            )

        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token missing sub claim",
            )
        return user_id
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
        )
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid JWT: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )
