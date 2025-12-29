"""
Health check endpoints for Kubernetes liveness/readiness probes.
"""

from fastapi import APIRouter, status
from pydantic import BaseModel

router = APIRouter()


class HealthResponse(BaseModel):
    """Health check response model."""
    status: str
    version: str
    spire: str = "not_initialized"
    vault: str = "not_initialized"
    database: str = "not_initialized"


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Health check",
    description="Basic health check endpoint for liveness probe"
)
async def health_check():
    """
    Health check endpoint.
    Returns 200 if the application is running.
    """
    from app.config import settings

    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION,
        # TODO: Add real status checks in later phases
    )


@router.get(
    "/health/ready",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Readiness check",
    description="Readiness check endpoint - verifies all dependencies are ready"
)
async def readiness_check():
    """
    Readiness check endpoint.
    Returns 200 only if SPIRE, Vault, and Database are ready.
    """
    from app.config import settings

    # TODO: Implement real readiness checks in later phases
    # - Check SPIRE connection
    # - Check Vault authentication
    # - Check database connection

    return HealthResponse(
        status="ready",
        version=settings.APP_VERSION,
    )
