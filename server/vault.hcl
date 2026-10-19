# Production server config: Raft integrated storage, TLS everywhere,
# AWS KMS auto-unseal (no Shamir key ceremony on every restart).
ui            = true
cluster_name  = "platform-vault"
disable_mlock = true # Raft + mlock is not recommended; swap is disabled on hosts instead

listener "tcp" {
  address                  = "[::]:8200"
  cluster_address          = "[::]:8201"
  tls_cert_file            = "/vault/tls/tls.crt"
  tls_key_file             = "/vault/tls/tls.key"
  tls_min_version          = "tls12"
  telemetry {
    unauthenticated_metrics_access = false
  }
}

storage "raft" {
  path    = "/vault/data"
  node_id = "VAULT_NODE_ID"

  retry_join {
    leader_api_addr     = "https://vault-0.vault-internal:8200"
    leader_ca_cert_file = "/vault/tls/ca.crt"
  }
  retry_join {
    leader_api_addr     = "https://vault-1.vault-internal:8200"
    leader_ca_cert_file = "/vault/tls/ca.crt"
  }
  retry_join {
    leader_api_addr     = "https://vault-2.vault-internal:8200"
    leader_ca_cert_file = "/vault/tls/ca.crt"
  }
}

# Key ID is a placeholder; Vault's IRSA role needs kms:Encrypt/Decrypt/DescribeKey on it.
seal "awskms" {
  region     = "us-east-2"
  kms_key_id = "alias/vault-unseal"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

api_addr     = "https://vault.vault.svc:8200"
cluster_addr = "https://POD_IP:8201"
