output "kubernetes_auth_path" {
  description = "Mount path for Kubernetes auth."
  value       = vault_auth_backend.kubernetes.path
}

output "policies" {
  description = "Policies managed by this config."
  value       = sort([for p in vault_policy.this : p.name])
}
