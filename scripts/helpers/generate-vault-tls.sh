#!/bin/bash
# Generate TLS certificates for OpenBao (production-grade configuration)
# This script creates a self-signed CA and server certificate for OpenBao
# In production, replace with certificates from your organization's PKI

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenBao TLS Certificate Generation${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Create temporary directory for certificates
CERT_DIR="$(mktemp -d)"
echo -e "${BLUE}ℹ️  Working directory: ${CERT_DIR}${NC}"

# Cleanup function
cleanup() {
    if [ -d "$CERT_DIR" ]; then
        rm -rf "$CERT_DIR"
        echo -e "${BLUE}ℹ️  Cleaned up temporary directory${NC}"
    fi
}
trap cleanup EXIT

#
# Step 1: Generate CA certificate
#
echo -e "\n${BLUE}📋 Step 1: Generating CA Certificate${NC}"

cat > "${CERT_DIR}/ca-config.json" <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "server": {
        "expiry": "8760h",
        "usages": [
          "signing",
          "key encipherment",
          "server auth"
        ]
      }
    }
  }
}
EOF

cat > "${CERT_DIR}/ca-csr.json" <<EOF
{
  "CN": "OpenBao CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Brooklyn",
      "O": "Precinct 99",
      "OU": "Security",
      "ST": "New York"
    }
  ]
}
EOF

# Check if cfssl is available, otherwise use openssl
if command -v cfssl &> /dev/null; then
    echo -e "${BLUE}Using cfssl for certificate generation${NC}"

    cd "${CERT_DIR}"
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

    # Generate server certificate
    cat > server-csr.json <<EOF
{
  "CN": "openbao.openbao.svc.cluster.local",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Brooklyn",
      "O": "Precinct 99",
      "OU": "Vault",
      "ST": "New York"
    }
  ],
  "hosts": [
    "openbao",
    "openbao.openbao",
    "openbao.openbao.svc",
    "openbao.openbao.svc.cluster.local",
    "localhost",
    "127.0.0.1"
  ]
}
EOF

    cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=server \
        server-csr.json | cfssljson -bare server

    CA_CERT="ca.pem"
    SERVER_CERT="server.pem"
    SERVER_KEY="server-key.pem"

else
    echo -e "${YELLOW}⚠️  cfssl not found, using openssl instead${NC}"

    # Generate CA with OpenSSL
    openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
        -keyout "${CERT_DIR}/ca-key.pem" \
        -out "${CERT_DIR}/ca.pem" \
        -subj "/C=US/ST=New York/L=Brooklyn/O=Precinct 99/OU=Security/CN=OpenBao CA"

    # Generate server certificate request
    openssl req -newkey rsa:2048 -nodes \
        -keyout "${CERT_DIR}/server-key.pem" \
        -out "${CERT_DIR}/server.csr" \
        -subj "/C=US/ST=New York/L=Brooklyn/O=Precinct 99/OU=Vault/CN=openbao.openbao.svc.cluster.local"

    # Create OpenSSL config for SAN
    cat > "${CERT_DIR}/server-ext.cnf" <<EOF
subjectAltName = @alt_names

[alt_names]
DNS.1 = openbao
DNS.2 = openbao.openbao
DNS.3 = openbao.openbao.svc
DNS.4 = openbao.openbao.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
EOF

    # Sign server certificate with CA
    openssl x509 -req -in "${CERT_DIR}/server.csr" \
        -CA "${CERT_DIR}/ca.pem" \
        -CAkey "${CERT_DIR}/ca-key.pem" \
        -CAcreateserial \
        -out "${CERT_DIR}/server.pem" \
        -days 365 \
        -extfile "${CERT_DIR}/server-ext.cnf"

    CA_CERT="ca.pem"
    SERVER_CERT="server.pem"
    SERVER_KEY="server-key.pem"
fi

echo -e "${GREEN}✅ Certificates generated successfully${NC}"

#
# Step 2: Verify certificates
#
echo -e "\n${BLUE}📋 Step 2: Verifying Certificates${NC}"

openssl x509 -in "${CERT_DIR}/${CA_CERT}" -noout -subject -issuer -dates
echo ""
openssl x509 -in "${CERT_DIR}/${SERVER_CERT}" -noout -subject -issuer -dates
echo ""
openssl verify -CAfile "${CERT_DIR}/${CA_CERT}" "${CERT_DIR}/${SERVER_CERT}"

echo -e "${GREEN}✅ Certificate verification passed${NC}"

#
# Step 3: Create Kubernetes secret
#
echo -e "\n${BLUE}📋 Step 3: Creating Kubernetes Secret${NC}"

# Delete existing secret if it exists
kubectl delete secret -n openbao openbao-tls 2>/dev/null || true

# Create new secret
kubectl create secret generic openbao-tls \
    -n openbao \
    --from-file=ca.crt="${CERT_DIR}/${CA_CERT}" \
    --from-file=server.crt="${CERT_DIR}/${SERVER_CERT}" \
    --from-file=server.key="${CERT_DIR}/${SERVER_KEY}"

echo -e "${GREEN}✅ Secret 'openbao-tls' created in namespace 'openbao'${NC}"

#
# Step 4: Save CA certificate for backend configuration
#
echo -e "\n${BLUE}📋 Step 4: Saving CA Certificate for Backend${NC}"

# Create directory if it doesn't exist
mkdir -p infrastructure/openbao/tls

# Copy CA cert for backend to trust
cp "${CERT_DIR}/${CA_CERT}" infrastructure/openbao/tls/ca.crt

echo -e "${GREEN}✅ CA certificate saved to infrastructure/openbao/tls/ca.crt${NC}"

#
# Summary
#
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✅ TLS Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Generated files:"
echo "  - Kubernetes secret: openbao-tls (namespace: openbao)"
echo "  - CA certificate: infrastructure/openbao/tls/ca.crt"
echo ""
echo "Next steps:"
echo "  1. Update OpenBao deployment to use TLS configuration"
echo "  2. Configure backend to use HTTPS and trust the CA"
echo "  3. Enable cert auth method in OpenBao"
