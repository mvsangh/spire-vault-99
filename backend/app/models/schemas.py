"""
Pydantic schemas for request/response validation.
"""

from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, EmailStr, Field, ConfigDict


# ============================================================================
# User Schemas
# ============================================================================

class UserCreate(BaseModel):
    """Schema for user registration."""
    username: str = Field(..., min_length=3, max_length=50, pattern="^[a-zA-Z0-9_-]+$")
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "username": "jake",
                "email": "jake@precinct99.com",
                "password": "secure_password_123"
            }
        }
    )


class UserLogin(BaseModel):
    """Schema for user login."""
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "username": "jake",
                "password": "secure_password_123"
            }
        }
    )


class UserResponse(BaseModel):
    """Schema for user response."""
    id: int
    username: str
    email: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": 1,
                "username": "jake",
                "email": "jake@precinct99.com",
                "created_at": "2025-01-01T12:00:00",
                "updated_at": "2025-01-01T12:00:00"
            }
        }
    )


class TokenResponse(BaseModel):
    """Schema for JWT token response."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "expires_in": 3600
            }
        }
    )


# ============================================================================
# GitHub Integration Schemas
# ============================================================================

class GitHubConfigRequest(BaseModel):
    """Schema for GitHub token configuration."""
    github_token: str = Field(..., min_length=40, max_length=100)

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "github_token": "ghp_1234567890abcdefghijklmnopqrstuvwxyzABCD"
            }
        }
    )


class GitHubConfigResponse(BaseModel):
    """Schema for GitHub configuration response."""
    message: str
    is_configured: bool
    configured_at: datetime

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "message": "GitHub token configured successfully",
                "is_configured": True,
                "configured_at": "2025-01-01T12:00:00"
            }
        }
    )


class GitHubRepository(BaseModel):
    """Schema for GitHub repository."""
    id: int
    name: str
    full_name: str
    description: Optional[str]
    private: bool
    html_url: str
    created_at: str
    updated_at: str
    language: Optional[str]
    stargazers_count: int
    forks_count: int

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": 123456,
                "name": "my-repo",
                "full_name": "jake/my-repo",
                "description": "A cool project",
                "private": False,
                "html_url": "https://github.com/jake/my-repo",
                "created_at": "2024-01-01T12:00:00Z",
                "updated_at": "2025-01-01T12:00:00Z",
                "language": "Python",
                "stargazers_count": 42,
                "forks_count": 7
            }
        }
    )


class GitHubUser(BaseModel):
    """Schema for GitHub user profile."""
    login: str
    id: int
    avatar_url: str
    html_url: str
    name: Optional[str]
    company: Optional[str]
    blog: Optional[str]
    location: Optional[str]
    email: Optional[str]
    bio: Optional[str]
    public_repos: int
    followers: int
    following: int
    created_at: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "login": "jake",
                "id": 123456,
                "avatar_url": "https://avatars.githubusercontent.com/u/123456",
                "html_url": "https://github.com/jake",
                "name": "Jake Peralta",
                "company": "NYPD",
                "blog": "https://precinct99.com",
                "location": "Brooklyn, NY",
                "email": "jake@precinct99.com",
                "bio": "Detective, Brooklyn Nine-Nine",
                "public_repos": 42,
                "followers": 99,
                "following": 15,
                "created_at": "2010-01-01T12:00:00Z"
            }
        }
    )


# ============================================================================
# Common Schemas
# ============================================================================

class ErrorResponse(BaseModel):
    """Schema for error responses."""
    detail: str
    error_code: Optional[str] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "detail": "Invalid credentials",
                "error_code": "AUTH_FAILED"
            }
        }
    )


class MessageResponse(BaseModel):
    """Schema for simple message responses."""
    message: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "message": "Operation completed successfully"
            }
        }
    )
