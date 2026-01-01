"""
Vault (OpenBao) client for secrets management.
Authenticates using SPIRE JWT-SVID via JWT auth method.
"""

import asyncio
import logging
import tempfile
from typing import Dict, Any, Optional
import hvac

from app.config import settings
from app.core.spire import spire_client

logger = logging.getLogger(__name__)


class VaultClient:
    """
    OpenBao client with JWT authentication using SPIRE JWT-SVID.
    Falls back to token auth for HTTP dev mode.
    """

    def __init__(self):
        """Initialize Vault client."""
        self.vault_addr = settings.VAULT_ADDR
        self.vault_cacert = settings.VAULT_CACERT
        self.kv_path = settings.VAULT_KV_PATH
        self.db_path = settings.VAULT_DB_PATH
        self.db_role = settings.VAULT_DB_ROLE
        self._client: Optional[hvac.Client] = None
        self._authenticated = False
        self._jwt_audiences: Optional[list] = None
        self._verify_param = None
        self._refresh_task: Optional[asyncio.Task] = None
        logger.info(f"Vault client initialized - Address: {self.vault_addr}")

    async def connect(self) -> None:
        """
        Connect to Vault and authenticate using SPIRE JWT-SVID (production) or token (dev mode).
        """
        try:
            # Check if we're using HTTPS (production) or HTTP (dev mode)
            is_https = self.vault_addr.startswith('https://')

            if is_https:
                # Production mode: Use JWT authentication with SPIRE JWT-SVID
                logger.info("Connecting to Vault with SPIRE JWT-SVID (JWT auth)...")

                # Store JWT audiences for later refresh
                from app.config import settings
                self._jwt_audiences = settings.JWT_SVID_AUDIENCE

                # Create Vault client (HTTPS)
                # Note: We can still verify TLS even without using cert auth
                import os
                vault_ca_path = None
                if self.vault_cacert:
                    # Resolve symlink to actual file (ConfigMap mounts use symlinks)
                    resolved_ca_path = os.path.realpath(self.vault_cacert)
                    if os.path.isfile(resolved_ca_path):
                        # Read CA cert and write to temp file for hvac
                        with open(resolved_ca_path, 'rb') as ca_file:
                            ca_cert_data = ca_file.read()

                        with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.crt') as ca_temp:
                            ca_temp.write(ca_cert_data)
                            vault_ca_path = ca_temp.name

                # Store verify param for later refresh
                self._verify_param = vault_ca_path if vault_ca_path else False

                self._client = hvac.Client(
                    url=self.vault_addr,
                    verify=self._verify_param
                )

                # Perform initial JWT authentication
                await self._authenticate_with_jwt()

                # Start background task to refresh JWT-SVID and re-authenticate
                self._refresh_task = asyncio.create_task(self._jwt_refresh_loop())
                logger.info("🔄 Started JWT-SVID refresh background task")

            else:
                # Dev mode (HTTP): Use token auth for local development
                logger.info("Connecting to Vault with token (HTTP dev mode)...")

                # Use root token for dev mode
                self._client = hvac.Client(
                    url=self.vault_addr,
                    token='root'  # Dev mode only - never use root token in production
                )

                # Verify authentication
                if self._client.is_authenticated():
                    self._authenticated = True
                    logger.info("✅ Vault authenticated (token) - Dev mode with root token")
                    logger.warning("⚠️  Using root token - For development only!")
                else:
                    raise RuntimeError("Token authentication failed")

        except Exception as e:
            logger.error(f"❌ Failed to authenticate to Vault: {e}")
            raise

    async def _authenticate_with_jwt(self) -> None:
        """
        Authenticate to Vault using SPIRE JWT-SVID.
        Can be called for initial auth or re-authentication.
        """
        # Fetch fresh JWT-SVID from SPIRE
        jwt_token = spire_client.fetch_jwt_svid(audiences=self._jwt_audiences)

        # Authenticate using JWT auth
        auth_response = self._client.auth.jwt.jwt_login(
            role='backend-role',
            jwt=jwt_token
        )

        self._authenticated = True
        logger.info(f"✅ Vault authenticated (JWT) - Token TTL: {auth_response['auth']['lease_duration']}s")
        logger.info(f"   Vault policies: {auth_response['auth']['policies']}")
        logger.info(f"   Entity ID: {auth_response['auth'].get('entity_id', 'N/A')}")

    async def _jwt_refresh_loop(self) -> None:
        """
        Background task that refreshes JWT-SVID and re-authenticates to Vault.
        Runs every 50 minutes to stay ahead of 1-hour JWT-SVID TTL.
        """
        refresh_interval = 3000  # 50 minutes in seconds

        while True:
            try:
                await asyncio.sleep(refresh_interval)

                logger.info("⏰ Starting JWT-SVID refresh and Vault re-authentication...")

                # Re-authenticate with fresh JWT-SVID
                await self._authenticate_with_jwt()

                logger.info("✅ JWT-SVID refresh completed successfully")

            except asyncio.CancelledError:
                logger.info("JWT refresh task cancelled")
                break
            except Exception as e:
                logger.error(f"❌ JWT refresh failed: {e}")
                logger.warning("⚠️  Will retry at next interval")
                # Don't break - keep trying at next interval

    def is_authenticated(self) -> bool:
        """Check if authenticated to Vault."""
        return self._authenticated and self._client is not None and self._client.is_authenticated()

    async def close(self) -> None:
        """Close Vault client and cancel background tasks."""
        if self._refresh_task:
            self._refresh_task.cancel()
            try:
                await self._refresh_task
            except asyncio.CancelledError:
                pass
            logger.info("Vault refresh task stopped")

    async def write_secret(self, path: str, data: Dict[str, Any]) -> None:
        """
        Write secret to KV v2 store.

        Args:
            path: Secret path (e.g., "github/api-token")
            data: Secret data (dict)
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        full_path = f"{self.kv_path}/data/{path}"

        try:
            self._client.secrets.kv.v2.create_or_update_secret(
                path=path,
                secret=data,
                mount_point=self.kv_path
            )
            logger.info(f"✅ Secret written to Vault: {full_path}")
        except Exception as e:
            logger.error(f"❌ Failed to write secret to {full_path}: {e}")
            raise

    async def read_secret(self, path: str) -> Dict[str, Any]:
        """
        Read secret from KV v2 store.

        Args:
            path: Secret path (e.g., "github/api-token")

        Returns:
            Secret data (dict)
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        full_path = f"{self.kv_path}/data/{path}"

        try:
            response = self._client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point=self.kv_path
            )
            logger.debug(f"✅ Secret read from Vault: {full_path}")
            return response['data']['data']
        except Exception as e:
            logger.error(f"❌ Failed to read secret from {full_path}: {e}")
            raise

    async def get_database_credentials(self) -> Dict[str, str]:
        """
        Get dynamic database credentials from Vault.

        Returns:
            Dict with 'username', 'password', and 'lease_id'
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        try:
            response = self._client.read(f"{self.db_path}/creds/{self.db_role}")

            username = response['data']['username']
            password = response['data']['password']
            lease_id = response['lease_id']
            lease_duration = response['lease_duration']

            logger.info(f"✅ Database credentials obtained - User: {username}, TTL: {lease_duration}s")

            return {
                'username': username,
                'password': password,
                'lease_id': lease_id,
                'lease_duration': lease_duration
            }
        except Exception as e:
            logger.error(f"❌ Failed to get database credentials: {e}")
            raise

    async def revoke_lease(self, lease_id: str) -> None:
        """
        Revoke a Vault lease (e.g., database credentials).

        Args:
            lease_id: Lease ID to revoke
        """
        if not self.is_authenticated():
            raise RuntimeError("Not authenticated to Vault")

        try:
            self._client.sys.revoke_lease(lease_id)
            logger.info(f"✅ Lease revoked: {lease_id}")
        except Exception as e:
            logger.error(f"❌ Failed to revoke lease {lease_id}: {e}")
            # Don't raise - lease will expire anyway


# Global Vault client instance
vault_client = VaultClient()
