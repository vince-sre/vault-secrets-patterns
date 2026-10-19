resource "vault_policy" "this" {
  for_each = fileset("${path.module}/../policies", "*.hcl")

  name   = trimsuffix(each.value, ".hcl")
  policy = file("${path.module}/../policies/${each.value}")
}

# ---- Kubernetes auth: pods log in with their service account token ----
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert == "" ? null : var.kubernetes_ca_cert
}

# One role per workload, pinned to namespace + service account and given
# exactly one policy. Tokens are short-lived and bound to the pod's audience.
resource "vault_kubernetes_auth_backend_role" "orders" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "orders"
  bound_service_account_names      = ["orders"]
  bound_service_account_namespaces = ["team-orders-prod", "team-orders-dev"]
  audience                         = "vault"
  token_policies                   = [vault_policy.this["app-orders.hcl"].name]
  token_ttl                        = 900
  token_max_ttl                    = 3600
}

# ---- JWT auth for GitHub Actions: no stored Vault token in CI ----
resource "vault_jwt_auth_backend" "github" {
  path               = "jwt-github"
  type               = "jwt"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}

resource "vault_jwt_auth_backend_role" "ci_deployer" {
  backend         = vault_jwt_auth_backend.github.path
  role_name       = "ci-deployer"
  role_type       = "jwt"
  user_claim      = "repository"
  bound_audiences = ["https://github.com/vince-sre"]
  bound_claims = {
    repository = "vince-sre/*"
    ref        = "refs/heads/main"
  }
  bound_claims_type = "glob"
  token_policies    = [vault_policy.this["ci-deployer.hcl"].name]
  token_ttl         = 600
}
