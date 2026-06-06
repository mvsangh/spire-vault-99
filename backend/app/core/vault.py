"""
Vault (OpenBao) client for secrets management.
Authenticates using SPIRE X.509-SVID via cert auth (mTLS) in HTTPS mode,
with JWT-SVID auth as an alternative, and root token in HTTP dev mode.
"""

import asyncio
import logging
import os
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
        self.auth_method = settings.VAULT_AUTH_METHOD
        self._jwt_audiences: Optional[list] = None
        self._verify_param = None
        self._cert_dir: Optional[str] = None  # tmpfs dir holding SVID cert/key for mTLS
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
                # Production mode: SPIRE-issued identity over TLS
                # Store JWT audiences in case JWT auth is selected or used as fallback
                from app.config import settings
                self._jwt_audiences = settings.JWT_SVID_AUDIENCE

                # Resolve CA certificate for server TLS verification
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
                if not vault_ca_path:
                    logger.warning("⚠️  VAULT_CACERT not set - server TLS verification disabled")

                if self.auth_method == 'cert':
                    # mTLS: authenticate with SPIRE X.509-SVID as client certificate
                    logger.info("Connecting to Vault with SPIRE X.509-SVID (cert auth / mTLS)...")
                    await self._authenticate_with_cert()
                else:
                    # JWT auth: SPIRE JWT-SVID over server-auth TLS
                    logger.info("Connecting to Vault with SPIRE JWT-SVID (JWT auth)...")
                    self._client = hvac.Client(
                        url=self.vault_addr,
                        verify=self._verify_param
                    )
                    await self._authenticate_with_jwt()

                # Start background task to refresh SVID and re-authenticate
                self._refresh_task = asyncio.create_task(self._auth_refresh_loop())
                logger.info(f"🔄 Started {self.auth_method} auth refresh background task")

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

    def _write_svid_material(self) -> tuple[str, str]:
        """
        Fetch a fresh X.509-SVID from SPIRE and write cert chain + private key
        to files with restrictive permissions (hvac/requests require file paths
        for client certificates).

        Returns:
            Tuple of (cert_path, key_path)
        """
        # Always refresh - SVIDs have a 1-hour TTL and re-auth may happen
        # long after the initial fetch
        spire_client.refresh_svid()

        if self._cert_dir is None:
            self._cert_dir = tempfile.mkdtemp(prefix='svid-')
            os.chmod(self._cert_dir, 0o700)

        cert_path = os.path.join(self._cert_dir, 'svid.crt')
        key_path = os.path.join(self._cert_dir, 'svid.key')

        # Write key first with 0600 before content lands on disk
        for path, data in ((cert_path, spire_client.get_certificate_pem()),
                           (key_path, spire_client.get_private_key_pem())):
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, 'wb') as f:
                f.write(data)

        return cert_path, key_path

    async def _authenticate_with_cert(self) -> None:
        """
        Authenticate to Vault using SPIRE X.509-SVID via cert auth (mTLS).
        Recreates the hvac client so the TLS session presents the fresh
        client certificate. Can be called for initial auth or re-authentication.
        """
        cert_path, key_path = self._write_svid_material()

        # New client per login - requests pins the client cert at session
        # level, so a rotated SVID requires a fresh session
        self._client = hvac.Client(
            url=self.vault_addr,
            cert=(cert_path, key_path),
            verify=self._verify_param
        )

        auth_response = self._client.auth.cert.login(name='backend-role')

        self._authenticated = True
        ttl = auth_response['auth']['lease_duration']
        logger.info(f"✅ Vault authenticated (cert/mTLS) - Token TTL: {ttl}s ({ttl//60} minutes)")
        logger.info(f"   Vault policies: {auth_response['auth']['policies']}")
        logger.info(f"   SPIFFE ID: {spire_client.get_spiffe_id()}")

        if not self._client.is_authenticated():
            raise RuntimeError("Cert authentication succeeded but Vault client is not authenticated")

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
        ttl = auth_response['auth']['lease_duration']
        logger.info(f"✅ Vault authenticated (JWT) - Token TTL: {ttl}s ({ttl//60} minutes)")
        logger.info(f"   Vault policies: {auth_response['auth']['policies']}")
        logger.info(f"   Entity ID: {auth_response['auth'].get('entity_id', 'N/A')}")

        # Verify authentication was successful
        if not self._client.is_authenticated():
            raise RuntimeError("JWT authentication succeeded but Vault client is not authenticated")

    async def _auth_refresh_loop(self) -> None:
        """
        Background task that refreshes the SVID and re-authenticates to Vault.
        Runs every 45 minutes to stay safely ahead of the 1-hour SVID TTL
        (both X.509-SVID for cert auth and JWT-SVID for JWT auth).
        """
        refresh_interval = 2700  # 45 minutes in seconds (1800s for 30min if needed)

        while True:
            try:
                await asyncio.sleep(refresh_interval)

                logger.info(f"⏰ Starting SVID refresh and Vault re-authentication ({self.auth_method})...")

                if self.auth_method == 'cert':
                    await self._authenticate_with_cert()
                else:
                    await self._authenticate_with_jwt()

                logger.info("✅ SVID refresh completed successfully")

            except asyncio.CancelledError:
                logger.info("Auth refresh task cancelled")
                break
            except Exception as e:
                logger.error(f"❌ Auth refresh failed: {e}")
                logger.warning("⚠️  Will retry at next interval")
                # Don't break - keep trying at next interval

    def is_authenticated(self) -> bool:
        """Check if authenticated to Vault with a valid token."""
        if not self._authenticated or self._client is None:
            return False

        # Check if hvac client has a token
        if not self._client.is_authenticated():
            return False

        # Check if the token is still valid (not expired)
        auth_info = self._client.auth.token.lookup_self()
        if 'errors' in auth_info:
            logger.warning("Vault token is invalid or expired")
            self._authenticated = False
            return False

        # None expire_time means a root/non-expiring token — valid in dev mode
        return True

    async def close(self) -> None:
        """Close Vault client and cancel background tasks."""
        if self._refresh_task:
            self._refresh_task.cancel()
            try:
                await self._refresh_task
            except asyncio.CancelledError:
                pass
            logger.info("Vault refresh task stopped")

        # Remove SVID material written for mTLS
        if self._cert_dir and os.path.isdir(self._cert_dir):
            import shutil
            shutil.rmtree(self._cert_dir, ignore_errors=True)
            self._cert_dir = None

    async def write_secret(self, path: str, data: Dict[str, Any]) -> None:
        """
        Write secret to KV v2 store.

        Args:
            path: Secret path (e.g., "github/api-token")
            data: Secret data (dict)
        """
        # Ensure authenticated before operation
        await self._ensure_authenticated()

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
        # Ensure authenticated before operation
        await self._ensure_authenticated()

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
        # Ensure authenticated before operation
        await self._ensure_authenticated()

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
        # Ensure authenticated before operation
        await self._ensure_authenticated()

        try:
            self._client.sys.revoke_lease(lease_id)
            logger.info(f"✅ Lease revoked: {lease_id}")
        except Exception as e:
            logger.error(f"❌ Failed to revoke lease {lease_id}: {e}")
            # Don't raise - lease will expire anyway

    async def _ensure_authenticated(self) -> None:
        """
        Ensure the Vault client is authenticated with a valid token.
        Re-authenticates if token is expired or missing.
        """
        if self.is_authenticated():
            return

        logger.info("🔄 Vault token expired or missing, re-authenticating...")
        is_https = self.vault_addr.startswith('https://')
        if is_https:
            if self.auth_method == 'cert':
                await self._authenticate_with_cert()
            else:
                await self._authenticate_with_jwt()
        else:
            self._client.token = 'root'
            self._authenticated = True
            logger.info("✅ Vault re-authenticated (dev mode root token)")
        logger.info("✅ Vault re-authentication successful")


# Global Vault client instance
vault_client = VaultClient()
