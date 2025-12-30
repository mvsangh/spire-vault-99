# OpenBao Production Configuration
# TLS-enabled with file storage backend

ui = true

# Storage backend - file-based (persistent)
# In production, use Consul, etcd, or cloud-native storage
storage "file" {
  path = "/vault/data"
}

# HTTPS listener with TLS
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false
  tls_cert_file = "/vault/tls/server.crt"
  tls_key_file  = "/vault/tls/server.key"

  # Client certificate authentication (optional, for mTLS)
  # tls_require_and_verify_client_cert = false
  # tls_client_ca_file = "/vault/tls/ca.crt"
}

# API address
api_addr = "https://openbao.openbao.svc.cluster.local:8200"

# Cluster address (for HA mode, not used in single instance)
cluster_addr = "https://openbao.openbao.svc.cluster.local:8201"

# Disable mlock for containerized environments
# In production with proper security, consider enabling mlock
disable_mlock = true

# Logging
log_level = "info"
log_format = "json"

# Telemetry (optional - can be configured for monitoring)
telemetry {
  disable_hostname = false
}
