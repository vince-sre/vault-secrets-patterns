variable "kubernetes_host" {
  description = "API server URL of the cluster whose service accounts authenticate to Vault."
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "kubernetes_ca_cert" {
  description = "PEM CA of that cluster. Empty when Vault runs in-cluster and reads its own SA CA."
  type        = string
  default     = ""
}

variable "db_connection_url" {
  description = "Postgres connection URL template, e.g. postgresql://{{username}}:{{password}}@db.internal:5432/orders"
  type        = string
  default     = "postgresql://{{username}}:{{password}}@orders-db.internal:5432/orders?sslmode=require"
}

variable "db_admin_username" {
  description = "Bootstrap DB user Vault uses to create dynamic users (rotated by Vault after setup)."
  type        = string
  default     = "vault_admin"
}

variable "db_admin_password" {
  description = "Bootstrap DB password. Supply via TF_VAR_db_admin_password; never commit."
  type        = string
  sensitive   = true
}

variable "audit_file_path" {
  description = "Where the file audit device writes."
  type        = string
  default     = "/vault/audit/audit.log"
}

variable "db_verify_connection" {
  description = "Verify DB connectivity when writing config (false for local dev without a DB)."
  type        = bool
  default     = true
}

variable "ci_deployer_role_arn" {
  description = "IAM role Vault assumes to mint short-lived CI credentials (placeholder account ID)."
  type        = string
  default     = "arn:aws:iam::111111111111:role/ci-deployer"
}
