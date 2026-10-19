# Platform operators: manage engines, auth methods and policies. Explicitly
# denied from reading application secret values (break-glass is a separate,
# audited root-token procedure).
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv/metadata/*" {
  capabilities = ["read", "list", "delete"]
}

path "kv/data/*" {
  capabilities = ["deny"]
}

path "sys/audit*" {
  capabilities = ["read", "list", "sudo"]
}
