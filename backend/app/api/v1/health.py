"""
Health check endpoints for Kubernetes liveness/readiness probes.
"""

from fastapi import APIRouter, status
from pydantic import BaseModel
from app.core.spire import spire_client
from app.core.vault import vault_client
from app.core.database import db_manager

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

    # Check SPIRE connection
    spire_status = "ready" if spire_client.is_connected() else "not_ready"

    # Check Vault authentication
    vault_status = "ready" if vault_client.is_authenticated() else "not_ready"

    # Check database connection
    database_status = "ready" if await db_manager.is_healthy() else "not_ready"

    return HealthResponse(
        status="ready" if (spire_status == "ready" and vault_status == "ready" and database_status == "ready") else "not_ready",
        version=settings.APP_VERSION,
        spire=spire_status,
        vault=vault_status,
        database=database_status,
    )
