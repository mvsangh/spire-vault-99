"""
Authentication endpoints (register, login, user info).
"""

import logging
from fastapi import APIRouter, HTTPException, status, Depends, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import db_manager
from app.core.auth import hash_password, verify_password, create_access_token, get_token_expiration_seconds, set_auth_cookie, clear_auth_cookie
from app.middleware.auth import get_current_user, CurrentUser
from app.models.models import User
from app.models.schemas import UserCreate, UserLogin, UserResponse, TokenResponse, AuthResponse, MessageResponse

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/register",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register new user",
    description="Register a new user account with username, email, and password"
)
async def register(user_data: UserCreate):
    """
    Register a new user.

    - Validates username, email, and password
    - Checks if username or email already exists
    - Hashes password with bcrypt
    - Creates user in database
    - Returns success message (user must login to get token)
    """
    async with db_manager.get_session() as session:
        # Check if username already exists
        result = await session.execute(
            select(User).where(User.username == user_data.username)
        )
        existing_user = result.scalar_one_or_none()

        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already registered"
            )

        # Check if email already exists
        result = await session.execute(
            select(User).where(User.email == user_data.email)
        )
        existing_email = result.scalar_one_or_none()

        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Hash password
        password_hash = hash_password(user_data.password)

        # Create new user
        new_user = User(
            username=user_data.username,
            email=user_data.email,
            password_hash=password_hash
        )

        session.add(new_user)
        await session.commit()

        logger.info(f"User registered: {user_data.username}")

        return MessageResponse(
            message=f"User '{user_data.username}' registered successfully. Please login to continue."
        )


@router.post(
    "/login",
    response_model=AuthResponse,
    status_code=status.HTTP_200_OK,
    summary="User login",
    description="Authenticate user and set httpOnly cookie with JWT token"
)
async def login(login_data: UserLogin, response: Response):
    """
    User login.

    - Validates username and password
    - Fetches user from database
    - Verifies password with bcrypt
    - Generates JWT token
    - Sets httpOnly cookie (token NOT returned in response body)
    - Returns success message and user data
    """
    async with db_manager.get_session() as session:
        # Fetch user by username
        result = await session.execute(
            select(User).where(User.username == login_data.username)
        )
        user = result.scalar_one_or_none()

        if not user:
            logger.warning(f"Login attempt for non-existent user: {login_data.username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )

        # Verify password
        if not verify_password(login_data.password, user.password_hash):
            logger.warning(f"Failed login attempt for user: {login_data.username}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid username or password",
            )

        # Create access token
        token_data = {
            "user_id": user.id,
            "username": user.username
        }
        access_token = create_access_token(token_data)

        # Set httpOnly cookie
        set_auth_cookie(response, access_token)

        logger.info(f"User logged in: {user.username}")

        return AuthResponse(
            message="Login successful",
            user=UserResponse.model_validate(user)
        )


@router.post(
    "/logout",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="User logout",
    description="Clear authentication cookie and logout user"
)
async def logout(response: Response, current_user: CurrentUser = Depends(get_current_user)):
    """
    User logout.

    - Protected route (requires valid JWT token)
    - Clears the httpOnly authentication cookie
    - Returns success message
    """
    clear_auth_cookie(response)

    logger.info(f"User logged out: {current_user.username}")

    return MessageResponse(
        message=f"Logout successful. Goodbye, {current_user.username}!"
    )


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user",
    description="Get current authenticated user information (protected route)"
)
async def get_me(current_user: CurrentUser = Depends(get_current_user)):
    """
    Get current user information.

    - Protected route (requires valid JWT token)
    - Returns user data from database
    """
    async with db_manager.get_session() as session:
        # Fetch user from database
        result = await session.execute(
            select(User).where(User.id == current_user.user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        return UserResponse.model_validate(user)
