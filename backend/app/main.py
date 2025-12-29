"""
Main FastAPI application for SPIRE-Vault-99 Backend.
"""

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.api.v1 import health
from app.core.spire import spire_client

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown events.
    """
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"SPIRE socket: {settings.SPIRE_SOCKET_PATH}")
    logger.info(f"Vault address: {settings.VAULT_ADDR}")
    logger.info(f"Database host: {settings.DB_HOST}")

    # Initialize SPIRE client
    try:
        await spire_client.connect()
        logger.info(f"✅ SPIRE initialized - ID: {spire_client.get_spiffe_id()}")
    except Exception as e:
        logger.error(f"❌ SPIRE initialization failed: {e}")
        raise

    # TODO: Initialize Vault client (Phase 3)
    # TODO: Initialize database pool (Phase 4)
    # TODO: Start credential rotation task (Phase 4)

    yield

    # Shutdown
    logger.info("Shutting down application...")
    await spire_client.close()
    # TODO: Close database pool (Phase 4)
    # TODO: Revoke Vault lease (Phase 4)
    logger.info("Shutdown complete")


# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Zero-trust demo platform with SPIRE/SPIFFE + OpenBao + Cilium",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_CREDENTIALS,
    allow_methods=settings.CORS_METHODS,
    allow_headers=settings.CORS_HEADERS,
)

# Include routers
app.include_router(health.router, prefix="/api/v1", tags=["health"])
# TODO: Add auth router (Phase 5)
# TODO: Add github router (Phase 6)

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
    }


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Handle uncaught exceptions."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )
