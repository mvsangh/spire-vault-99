"""
GitHub integration endpoints (configure, repos, user profile).
"""

import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import db_manager
from app.core.vault import vault_client
from app.core.github import github_client, GitHubAPIError
from app.middleware.auth import get_current_user, CurrentUser
from app.models.models import User, GitHubIntegration
from app.models.schemas import (
    GitHubConfigRequest,
    GitHubConfigResponse,
    GitHubRepository,
    GitHubUser,
    MessageResponse
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/configure",
    response_model=GitHubConfigResponse,
    status_code=status.HTTP_200_OK,
    summary="Configure GitHub token",
    description="Store GitHub Personal Access Token in Vault (protected route)"
)
async def configure_github(
    config_data: GitHubConfigRequest,
    current_user: CurrentUser = Depends(get_current_user)
):
    """
    Configure GitHub integration by storing PAT in Vault.

    - Protected route (requires JWT token)
    - Stores GitHub token in Vault at secret/data/github/user-{user_id}/token
    - Updates github_integrations table with configuration status
    - Returns success response with configuration timestamp
    """
    user_id = current_user.user_id

    # Store token in Vault
    vault_path = f"github/user-{user_id}/token"
    token_data = {"token": config_data.github_token}

    try:
        await vault_client.write_secret(vault_path, token_data)
        logger.info(f"GitHub token stored in Vault for user {user_id}")
    except Exception as e:
        logger.error(f"Failed to store GitHub token in Vault: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to store GitHub token"
        )

    # Update database
    async with db_manager.get_session() as session:
        # Check if integration record exists
        result = await session.execute(
            select(GitHubIntegration).where(GitHubIntegration.user_id == user_id)
        )
        integration = result.scalar_one_or_none()

        now = datetime.utcnow()

        if integration:
            # Update existing record
            integration.is_configured = True
            integration.configured_at = now
            integration.updated_at = now
        else:
            # Create new record
            integration = GitHubIntegration(
                user_id=user_id,
                is_configured=True,
                configured_at=now
            )
            session.add(integration)

        await session.commit()

        logger.info(f"GitHub integration configured for user {user_id}")

        return GitHubConfigResponse(
            message="GitHub token configured successfully",
            is_configured=True,
            configured_at=now
        )


@router.get(
    "/repos",
    response_model=list[GitHubRepository],
    status_code=status.HTTP_200_OK,
    summary="List GitHub repositories",
    description="Fetch user's GitHub repositories (protected route)"
)
async def list_repositories(current_user: CurrentUser = Depends(get_current_user)):
    """
    List user's GitHub repositories.

    - Protected route (requires JWT token)
    - Retrieves GitHub token from Vault
    - Calls GitHub API /user/repos
    - Updates last_accessed timestamp
    - Returns list of repositories
    """
    user_id = current_user.user_id

    # Retrieve token from Vault
    vault_path = f"github/user-{user_id}/token"

    try:
        token_data = await vault_client.read_secret(vault_path)
        github_token = token_data.get("token")

        if not github_token:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="GitHub token not configured. Please configure first."
            )

    except Exception as e:
        logger.error(f"Failed to retrieve GitHub token from Vault: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="GitHub token not configured. Please configure first."
        )

    # Fetch repositories from GitHub
    try:
        repos = await github_client.fetch_repositories(github_token)
    except GitHubAPIError as e:
        logger.error(f"GitHub API error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e)
        )

    # Update last_accessed timestamp
    async with db_manager.get_session() as session:
        result = await session.execute(
            select(GitHubIntegration).where(GitHubIntegration.user_id == user_id)
        )
        integration = result.scalar_one_or_none()

        if integration:
            integration.last_accessed_at = datetime.utcnow()
            integration.updated_at = datetime.utcnow()
            await session.commit()

    logger.info(f"User {user_id} fetched {len(repos)} repositories")

    return repos


@router.get(
    "/user",
    response_model=GitHubUser,
    status_code=status.HTTP_200_OK,
    summary="Get GitHub user profile",
    description="Fetch user's GitHub profile (protected route)"
)
async def get_github_user(current_user: CurrentUser = Depends(get_current_user)):
    """
    Get user's GitHub profile.

    - Protected route (requires JWT token)
    - Retrieves GitHub token from Vault
    - Calls GitHub API /user
    - Returns GitHub user profile
    """
    user_id = current_user.user_id

    # Retrieve token from Vault
    vault_path = f"github/user-{user_id}/token"

    try:
        token_data = await vault_client.read_secret(vault_path)
        github_token = token_data.get("token")

        if not github_token:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="GitHub token not configured. Please configure first."
            )

    except Exception as e:
        logger.error(f"Failed to retrieve GitHub token from Vault: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="GitHub token not configured. Please configure first."
        )

    # Fetch user profile from GitHub
    try:
        user_profile = await github_client.fetch_user_profile(github_token)
    except GitHubAPIError as e:
        logger.error(f"GitHub API error: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(e)
        )

    logger.info(f"User {user_id} fetched GitHub profile")

    return user_profile
