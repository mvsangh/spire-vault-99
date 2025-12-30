"""
SPIRE client for workload identity.
Fetches X.509-SVID from SPIRE agent via Workload API.
"""

import logging
from typing import Optional
from spiffe import WorkloadApiClient, X509Svid, SpiffeId
from cryptography.hazmat.primitives import serialization

from app.config import settings

logger = logging.getLogger(__name__)


class SPIREClient:
    """
    SPIRE Workload API client.
    Manages X.509-SVID acquisition and rotation.
    """

    def __init__(self, socket_path: str = settings.SPIRE_SOCKET_PATH):
        """
        Initialize SPIRE client.

        Args:
            socket_path: Path to SPIRE agent socket
        """
        self.socket_path = socket_path
        self._client: Optional[WorkloadApiClient] = None
        self._svid: Optional[X509Svid] = None
        self._spiffe_id: Optional[SpiffeId] = None
        logger.info(f"SPIRE client initialized with socket: {socket_path}")

    async def connect(self) -> None:
        """
        Connect to SPIRE agent and fetch initial SVID.
        """
        try:
            logger.info("Connecting to SPIRE agent...")

            # Create Workload API client
            # SPIFFE library requires unix:// scheme
            socket_url = f"unix://{self.socket_path}"
            self._client = WorkloadApiClient(socket_url)

            # Fetch X.509-SVID
            self._svid = self._client.fetch_x509_svid()
            self._spiffe_id = self._svid.spiffe_id

            logger.info(f"✅ SPIRE connected - SPIFFE ID: {self._spiffe_id}")

        except Exception as e:
            logger.error(f"❌ Failed to connect to SPIRE: {e}")
            raise

    async def close(self) -> None:
        """Close SPIRE client connection."""
        if self._client:
            self._client.close()
            logger.info("SPIRE client closed")

    def get_svid(self) -> X509Svid:
        """
        Get current X.509-SVID.

        Returns:
            Current X.509-SVID

        Raises:
            RuntimeError: If SVID not available
        """
        if not self._svid:
            raise RuntimeError("SVID not available - call connect() first")
        return self._svid

    def get_spiffe_id(self) -> str:
        """
        Get SPIFFE ID as string.

        Returns:
            SPIFFE ID (e.g., spiffe://demo.local/ns/99-apps/sa/backend)
        """
        if not self._spiffe_id:
            raise RuntimeError("SPIFFE ID not available - call connect() first")
        return str(self._spiffe_id)

    def get_certificate_pem(self) -> bytes:
        """
        Get certificate chain in PEM format for mTLS.
        Returns the FULL chain including leaf and intermediate certificates.

        Returns:
            Full certificate chain in PEM format (concatenated)
        """
        svid = self.get_svid()
        # The spiffe library uses cert_chain (list of cryptography Certificate objects)
        # Convert FULL chain to PEM bytes - Vault needs the complete chain for validation
        cert_chain_pem = b''
        for cert in svid.cert_chain:
            cert_chain_pem += cert.public_bytes(encoding=serialization.Encoding.PEM)
        return cert_chain_pem

    def get_private_key_pem(self) -> bytes:
        """
        Get private key in PEM format for mTLS.

        Returns:
            Private key in PEM format
        """
        svid = self.get_svid()
        # The spiffe library uses private_key (cryptography PrivateKey object)
        # Convert to PEM bytes using cryptography API
        return svid.private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        )

    def is_connected(self) -> bool:
        """Check if connected to SPIRE and SVID is available."""
        return self._svid is not None

    def fetch_jwt_svid(self, audiences: list[str]) -> str:
        """
        Fetch JWT-SVID from SPIRE agent for OpenBao authentication.

        Args:
            audiences: List of audience values for the JWT (e.g., ["openbao", "vault"])

        Returns:
            JWT token as string

        Raises:
            RuntimeError: If client not connected

        Note:
            This method fetches a fresh JWT-SVID on each call. For production use,
            consider implementing token caching with automatic refresh before expiry.
        """
        if not self._client:
            raise RuntimeError("SPIRE client not connected - call connect() first")

        try:
            logger.info(f"Fetching JWT-SVID with audiences: {audiences}")

            # Fetch JWT-SVID bundle with specified audiences
            # The SPIRE agent will return a JWT token signed by the SPIRE server
            jwt_bundle = self._client.fetch_jwt_bundles()

            # Fetch JWT-SVID with audiences (py-spiffe expects a set, not list)
            jwt_svid = self._client.fetch_jwt_svid(audience=set(audiences))

            # Extract token string
            token = jwt_svid.token

            logger.info(f"✅ JWT-SVID fetched successfully")
            logger.info(f"   SPIFFE ID: {jwt_svid.spiffe_id}")
            logger.info(f"   Token expires at: {jwt_svid.expiry}")

            return token

        except Exception as e:
            logger.error(f"❌ Failed to fetch JWT-SVID: {e}")
            raise


# Global SPIRE client instance
spire_client = SPIREClient()
