"""
GitHub API client for repository and user profile operations.
"""

import logging
from typing import List, Dict, Any
import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class GitHubAPIError(Exception):
    """Exception raised for GitHub API errors."""
    pass


class GitHubClient:
    """
    GitHub API client.
    Handles repository listing and user profile fetching.
    """

    def __init__(self):
        """Initialize GitHub client."""
        self.base_url = settings.GITHUB_API_URL
        self.timeout = 10.0  # seconds

    async def fetch_repositories(self, token: str) -> List[Dict[str, Any]]:
        """
        Fetch user's repositories from GitHub.

        Args:
            token: GitHub Personal Access Token

        Returns:
            List of repository dictionaries

        Raises:
            GitHubAPIError: If API request fails
        """
        url = f"{self.base_url}/user/repos"
        headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json"
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, headers=headers)

                if response.status_code == 401:
                    logger.warning("GitHub API: Unauthorized - invalid token")
                    raise GitHubAPIError("Invalid GitHub token")

                if response.status_code == 403:
                    logger.warning("GitHub API: Forbidden - rate limit or token permissions")
                    raise GitHubAPIError("GitHub API rate limit exceeded or insufficient permissions")

                if response.status_code != 200:
                    logger.error(f"GitHub API error: {response.status_code} - {response.text}")
                    raise GitHubAPIError(f"GitHub API request failed: {response.status_code}")

                repos = response.json()
                logger.info(f"Fetched {len(repos)} repositories from GitHub")
                return repos

        except httpx.TimeoutException:
            logger.error("GitHub API timeout")
            raise GitHubAPIError("GitHub API request timed out")
        except httpx.RequestError as e:
            logger.error(f"GitHub API request error: {e}")
            raise GitHubAPIError(f"GitHub API request failed: {str(e)}")

    async def fetch_user_profile(self, token: str) -> Dict[str, Any]:
        """
        Fetch user's GitHub profile.

        Args:
            token: GitHub Personal Access Token

        Returns:
            User profile dictionary

        Raises:
            GitHubAPIError: If API request fails
        """
        url = f"{self.base_url}/user"
        headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json"
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, headers=headers)

                if response.status_code == 401:
                    logger.warning("GitHub API: Unauthorized - invalid token")
                    raise GitHubAPIError("Invalid GitHub token")

                if response.status_code == 403:
                    logger.warning("GitHub API: Forbidden - rate limit or token permissions")
                    raise GitHubAPIError("GitHub API rate limit exceeded or insufficient permissions")

                if response.status_code != 200:
                    logger.error(f"GitHub API error: {response.status_code} - {response.text}")
                    raise GitHubAPIError(f"GitHub API request failed: {response.status_code}")

                user_profile = response.json()
                logger.info(f"Fetched GitHub profile for user: {user_profile.get('login')}")
                return user_profile

        except httpx.TimeoutException:
            logger.error("GitHub API timeout")
            raise GitHubAPIError("GitHub API request timed out")
        except httpx.RequestError as e:
            logger.error(f"GitHub API request error: {e}")
            raise GitHubAPIError(f"GitHub API request failed: {str(e)}")


# Global GitHub client instance
github_client = GitHubClient()
