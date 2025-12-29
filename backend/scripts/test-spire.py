"""
Test script to verify SPIRE integration.
Run inside a pod with SPIRE socket access.
"""

import sys
from spiffe.workloadapi import WorkloadApiClient


def test_spire():
    socket_path = "/run/spire/sockets/agent.sock"

    print(f"🔍 Testing SPIRE connection...")
    print(f"Socket path: {socket_path}")

    try:
        client = WorkloadApiClient(socket_path)
        svid = client.fetch_x509_svid()

        print(f"✅ SPIRE connection successful!")
        print(f"SPIFFE ID: {svid.spiffe_id}")
        print(f"Expires: {svid.not_after}")
        print(f"Certificate chain length: {len(svid.cert_chain)}")

        client.close()
        return 0
    except Exception as e:
        print(f"❌ SPIRE connection failed: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(test_spire())
