# ---- KV v2 for static secrets ----
resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  description = "Static application secrets (versioned)"
  options = {
    version = "2"
  }
}

resource "vault_kv_secret_backend_v2" "kv" {
  mount                = vault_mount.kv.path
  max_versions         = 10
  delete_version_after = 0
  cas_required         = true # writes must pass check-and-set, so no blind overwrites
}

# ---- Transit: encryption as a service ----
resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "Envelope encryption for application data"
}

resource "vault_transit_secret_backend_key" "orders" {
  backend                = vault_mount.transit.path
  name                   = "orders"
  type                   = "aes256-gcm96"
  deletion_allowed       = false
  exportable             = false
  auto_rotate_period     = 60 * 60 * 24 * 30 # monthly
  min_decryption_version = 1
}

# ---- Database: dynamic Postgres credentials ----
resource "vault_database_secrets_mount" "db" {
  path = "database"

  postgresql {
    name                 = "orders"
    connection_url       = var.db_connection_url
    username             = var.db_admin_username
    password             = var.db_admin_password
    verify_connection    = var.db_verify_connection
    allowed_roles        = ["orders-app"]
    max_open_connections = 5
  }
}

resource "vault_database_secret_backend_role" "orders_app" {
  backend     = vault_database_secrets_mount.db.path
  name        = "orders-app"
  db_name     = "orders"
  default_ttl = 3600
  max_ttl     = 14400

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT orders_rw TO \"{{name}}\";",
  ]
  revocation_statements = [
    "REVOKE orders_rw FROM \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";",
  ]
}

# ---- AWS: short-lived STS credentials for CI ----
resource "vault_aws_secret_backend" "aws" {
  path                      = "aws"
  description               = "Short-lived AWS credentials via AssumeRole"
  default_lease_ttl_seconds = 900
  max_lease_ttl_seconds     = 3600
  # No static keys: in AWS, Vault uses its own instance/IRSA identity.
}

resource "vault_aws_secret_backend_role" "ci_deployer" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "ci-deployer"
  credential_type = "assumed_role"
  role_arns       = [var.ci_deployer_role_arn]
  default_sts_ttl = 900
  max_sts_ttl     = 3600
}
