"""
Authentication utilities for password hashing and JWT token management.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import bcrypt
from jose import JWTError, jwt
from fastapi import Response, Request, HTTPException, status

from app.config import settings

logger = logging.getLogger(__name__)


def hash_password(password: str) -> str:
    """
    Hash a password using bcrypt.

    Args:
        password: Plain text password

    Returns:
        Hashed password string
    """
    salt = bcrypt.gensalt(rounds=settings.BCRYPT_ROUNDS)
    password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
    return password_hash.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a password against its hash.

    Args:
        plain_password: Plain text password
        hashed_password: Hashed password from database

    Returns:
        True if password matches, False otherwise
    """
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """
    Create a JWT access token.

    Args:
        data: Data to encode in the token (typically user_id, username)
        expires_delta: Optional custom expiration time

    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()

    # Set expiration time
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire, "iat": datetime.utcnow()})

    # Encode token
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode and validate a JWT access token.

    Args:
        token: JWT token string

    Returns:
        Decoded token payload if valid, None otherwise
    """
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError as e:
        logger.warning(f"JWT decode error: {e}")
        return None
    except Exception as e:
        logger.error(f"Token decode error: {e}")
        return None


def get_token_expiration_seconds() -> int:
    """
    Get token expiration time in seconds.

    Returns:
        Token expiration time in seconds
    """
    return settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60


# ============================================================================
# Cookie-based Authentication Functions
# ============================================================================

def set_auth_cookie(response: Response, token: str) -> None:
    """
    Set httpOnly authentication cookie in response.

    Args:
        response: FastAPI Response object
        token: JWT access token
    """
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,  # Prevents JavaScript access (XSS protection)
        secure=False,  # Set to True in production (HTTPS only)
        samesite="lax",  # CSRF protection
        max_age=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # Convert to seconds
        path="/",
    )
    logger.debug("Auth cookie set (httpOnly, SameSite=Lax)")


def clear_auth_cookie(response: Response) -> None:
    """
    Clear authentication cookie (for logout).

    Args:
        response: FastAPI Response object
    """
    response.delete_cookie(
        key="access_token",
        httponly=True,
        secure=False,
        samesite="lax",
        path="/",
    )
    logger.debug("Auth cookie cleared")


def get_token_from_cookie(request: Request) -> str:
    """
    Extract JWT token from httpOnly cookie.

    Args:
        request: FastAPI Request object

    Returns:
        JWT token string

    Raises:
        HTTPException: If cookie not found
    """
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated - no auth cookie found",
        )
    return token
