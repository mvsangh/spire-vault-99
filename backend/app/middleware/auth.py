"""
Authentication middleware for JWT token validation.
"""

import logging
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.auth import decode_access_token

logger = logging.getLogger(__name__)

# HTTP Bearer token scheme
security = HTTPBearer()


class CurrentUser:
    """Current authenticated user information."""

    def __init__(self, user_id: int, username: str):
        self.user_id = user_id
        self.username = username

    def __repr__(self):
        return f"<CurrentUser(user_id={self.user_id}, username='{self.username}')>"


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> CurrentUser:
    """
    Dependency to get current authenticated user from JWT token.

    Validates the JWT token from the Authorization header and extracts user information.

    Args:
        credentials: HTTP Bearer credentials from Authorization header

    Returns:
        CurrentUser instance with user_id and username

    Raises:
        HTTPException: 401 if token is invalid or missing
    """
    token = credentials.credentials

    # Decode and validate token
    payload = decode_access_token(token)

    if payload is None:
        logger.warning("Invalid or expired JWT token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Extract user information
    user_id: Optional[int] = payload.get("user_id")
    username: Optional[str] = payload.get("username")

    if user_id is None or username is None:
        logger.warning("Token missing user_id or username")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return CurrentUser(user_id=user_id, username=username)
