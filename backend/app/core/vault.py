"""
Vault (OpenBao) client for secrets management.
Authenticates using SPIRE X.509-SVID via mTLS.
"""

import logging
import tempfile
from typing import Dict, Any, Optional
import hvac

from app.config import settings
from app.core.spire import spire_client

logger = logging.getLogger(__name__)


class VaultClient:
    """
    OpenBao client with mTLS authentication using SPIRE certificates.
    """

    def __init__(self):
        """Initialize Vault client."""
        self.vault_addr = settings.VAULT_ADDR
        self.kv_path = settings.VAULT_KV_PATH
        self.db_path = settings.VAULT_DB_PATH
        self.db_role = settings.VAULT_DB_ROLE
        self._client: Optional[hvac.Client] = None
        self._authenticated = False
        logger.info(f"Vault client initialized - Address: {self.vault_addr}")

    async def connect(self) -> None:
        """
        Connect to Vault and authenticate using SPIRE certificate.
        """
        try:
            logger.info("Connecting to Vault with SPIRE certificate...")

            # Get SPIRE certificate and key
            cert_pem = spire_client.get_certificate_pem()
            key_pem = spire_client.get_private_key_pem()

            # Write cert and key to temporary files (required by hvac)
            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as cert_file:
                cert_file.write(cert_pem)
                cert_path = cert_file.name

            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as key_file:
                key_file.write(key_pem)
                key_path = key_file.name

            # Create Vault client with mTLS
            self._client = hvac.Client(
                url=self.vault_addr,
                cert=(cert_path, key_path),
                verify=False  # Dev mode - in production, verify=True with CA bundle
            )

            # Authenticate using cert auth
            auth_response = self._client.auth.cert.login()

            self._authenticated = True
            logger.info(f"✅ Vault authenticated - Token TTL: {auth_response['auth']['lease_duration']}s")
            logger.info(f"Vault policies: {auth_response['auth']['policies']}")

        except Exception as e:
            logger.error(f"❌ Failed to authenticate to Vault: {e}")
            raise

    def is_authenticated(self) -> bool:
        """Check if authenticated to Vault."""
        return self._authenticated and self._client is not None and self._client.is_authenticated()

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
