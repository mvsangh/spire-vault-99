"""
SPIRE client for workload identity.
Fetches X.509-SVID from SPIRE agent via Workload API.
"""

import logging
from typing import Optional
from spiffe.workloadapi import WorkloadApiClient
from spiffe.x509svid import X509Svid
from spiffe.spiffe_id import SpiffeId

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
            self._client = WorkloadApiClient(self.socket_path)

            # Fetch X.509-SVID
            self._svid = self._client.fetch_x509_svid()
            self._spiffe_id = self._svid.spiffe_id

            logger.info(f"✅ SPIRE connected - SPIFFE ID: {self._spiffe_id}")
            logger.info(f"SVID expires at: {self._svid.not_after}")

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
        Get certificate in PEM format for mTLS.

        Returns:
            Certificate chain in PEM format
        """
        svid = self.get_svid()
        return svid.cert_chain_pem

    def get_private_key_pem(self) -> bytes:
        """
        Get private key in PEM format for mTLS.

        Returns:
            Private key in PEM format
        """
        svid = self.get_svid()
        return svid.private_key_pem

    def is_connected(self) -> bool:
        """Check if connected to SPIRE and SVID is available."""
        return self._svid is not None


# Global SPIRE client instance
spire_client = SPIREClient()
