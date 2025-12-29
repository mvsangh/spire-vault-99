"""
Database connection manager with Vault dynamic credentials and automatic rotation.
"""

import logging
import asyncio
from typing import Optional
from sqlalchemy.ext.asyncio import create_async_engine, AsyncEngine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool

from app.config import settings
from app.core.vault import vault_client

logger = logging.getLogger(__name__)

# SQLAlchemy Base for models
Base = declarative_base()


class DatabaseManager:
    """
    Database connection manager with dynamic credentials from Vault.
    Handles connection pool creation, credential rotation, and graceful migration.
    """

    def __init__(self):
        """Initialize database manager."""
        self._engine: Optional[AsyncEngine] = None
        self._session_factory: Optional[sessionmaker] = None
        self._current_lease_id: Optional[str] = None
        self._rotation_task: Optional[asyncio.Task] = None
        self._is_rotating = False
        logger.info("Database manager initialized")

    async def connect(self) -> None:
        """
        Connect to database with Vault dynamic credentials.
        Creates initial connection pool.
        """
        try:
            logger.info("Fetching database credentials from Vault...")

            # Get dynamic credentials from Vault
            creds = await vault_client.get_database_credentials()

            username = creds['username']
            password = creds['password']
            self._current_lease_id = creds['lease_id']

            logger.info(f"✅ Database credentials obtained - User: {username}, Lease: {self._current_lease_id[:8]}...")

            # Create connection string
            db_url = (
                f"postgresql+asyncpg://{username}:{password}"
                f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
            )

            # Create async engine with connection pool
            self._engine = create_async_engine(
                db_url,
                pool_size=settings.DB_POOL_SIZE,
                max_overflow=settings.DB_MAX_OVERFLOW,
                pool_pre_ping=True,  # Test connections before using
                echo=settings.DB_ECHO,
            )

            # Create session factory
            self._session_factory = sessionmaker(
                self._engine,
                class_=AsyncSession,
                expire_on_commit=False,
            )

            # Test connection
            async with self._engine.begin() as conn:
                await conn.execute("SELECT 1")

            logger.info(f"✅ Database connected - Pool size: {settings.DB_POOL_SIZE}, Max overflow: {settings.DB_MAX_OVERFLOW}")

            # Start credential rotation task
            self._rotation_task = asyncio.create_task(self._credential_rotation_loop())
            logger.info(f"✅ Credential rotation task started - Interval: {settings.DB_CREDENTIAL_ROTATION_INTERVAL}s")

        except Exception as e:
            logger.error(f"❌ Failed to connect to database: {e}")
            raise

    async def close(self) -> None:
        """
        Close database connection and revoke credentials.
        """
        logger.info("Closing database connection...")

        # Cancel rotation task
        if self._rotation_task:
            self._rotation_task.cancel()
            try:
                await self._rotation_task
            except asyncio.CancelledError:
                pass
            logger.info("Credential rotation task stopped")

        # Close engine
        if self._engine:
            await self._engine.dispose()
            logger.info("Database engine disposed")

        # Revoke current lease
        if self._current_lease_id:
            try:
                await vault_client.revoke_lease(self._current_lease_id)
                logger.info(f"Lease revoked: {self._current_lease_id[:8]}...")
            except Exception as e:
                logger.warning(f"Failed to revoke lease: {e}")

        logger.info("Database connection closed")

    async def _credential_rotation_loop(self) -> None:
        """
        Background task to rotate database credentials periodically.
        Rotates every DB_CREDENTIAL_ROTATION_INTERVAL seconds (default: 3000s / 50 minutes).
        """
        while True:
            try:
                # Wait for rotation interval
                await asyncio.sleep(settings.DB_CREDENTIAL_ROTATION_INTERVAL)

                logger.info("⏰ Starting credential rotation...")
                await self._rotate_credentials()
                logger.info("✅ Credential rotation completed")

            except asyncio.CancelledError:
                logger.info("Credential rotation task cancelled")
                raise
            except Exception as e:
                logger.error(f"❌ Credential rotation failed: {e}")
                logger.warning("Will retry at next interval")

    async def _rotate_credentials(self) -> None:
        """
        Rotate database credentials with graceful pool migration.

        Steps:
        1. Fetch new credentials from Vault
        2. Create new engine with new credentials
        3. Test new connection
        4. Swap to new engine
        5. Dispose old engine
        6. Revoke old lease
        """
        if self._is_rotating:
            logger.warning("Credential rotation already in progress, skipping")
            return

        self._is_rotating = True
        old_engine = self._engine
        old_lease_id = self._current_lease_id

        try:
            # Step 1: Fetch new credentials
            logger.info("Fetching new database credentials from Vault...")
            creds = await vault_client.get_database_credentials()

            username = creds['username']
            password = creds['password']
            new_lease_id = creds['lease_id']

            logger.info(f"New credentials obtained - User: {username}, Lease: {new_lease_id[:8]}...")

            # Step 2: Create new engine
            db_url = (
                f"postgresql+asyncpg://{username}:{password}"
                f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
            )

            new_engine = create_async_engine(
                db_url,
                pool_size=settings.DB_POOL_SIZE,
                max_overflow=settings.DB_MAX_OVERFLOW,
                pool_pre_ping=True,
                echo=settings.DB_ECHO,
            )

            # Step 3: Test new connection
            async with new_engine.begin() as conn:
                await conn.execute("SELECT 1")

            logger.info("✅ New database connection tested successfully")

            # Step 4: Swap to new engine (atomic swap)
            self._engine = new_engine
            self._current_lease_id = new_lease_id

            # Update session factory
            self._session_factory = sessionmaker(
                self._engine,
                class_=AsyncSession,
                expire_on_commit=False,
            )

            logger.info("✅ Swapped to new database engine")

            # Step 5: Dispose old engine (graceful shutdown)
            if old_engine:
                await old_engine.dispose()
                logger.info("Old database engine disposed")

            # Step 6: Revoke old lease
            if old_lease_id:
                try:
                    await vault_client.revoke_lease(old_lease_id)
                    logger.info(f"Old lease revoked: {old_lease_id[:8]}...")
                except Exception as e:
                    logger.warning(f"Failed to revoke old lease: {e}")

            logger.info("✅ Credential rotation completed successfully")

        except Exception as e:
            logger.error(f"❌ Credential rotation failed: {e}")
            # Restore old engine if swap failed
            if old_engine and not self._engine:
                self._engine = old_engine
                self._current_lease_id = old_lease_id
                logger.warning("Restored old database engine")
            raise

        finally:
            self._is_rotating = False

    def get_session(self) -> AsyncSession:
        """
        Get database session.

        Returns:
            AsyncSession instance

        Raises:
            RuntimeError: If database not connected
        """
        if not self._session_factory:
            raise RuntimeError("Database not connected - call connect() first")
        return self._session_factory()

    async def is_healthy(self) -> bool:
        """
        Check database health.

        Returns:
            True if database is healthy, False otherwise
        """
        if not self._engine:
            return False

        try:
            async with self._engine.begin() as conn:
                await conn.execute("SELECT 1")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False


# Global database manager instance
db_manager = DatabaseManager()
