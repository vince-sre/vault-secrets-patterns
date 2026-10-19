# Workload policy for the orders service. Read-only, and only its own paths.

# Static config/secrets (KV v2: data/ for values, metadata/ for listing)
path "kv/data/apps/orders/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/orders/*" {
  capabilities = ["list"]
}

# Short-lived database credentials
path "database/creds/orders-app" {
  capabilities = ["read"]
}

# Encryption as a service: encrypt/decrypt with its own key, never export it
path "transit/encrypt/orders" {
  capabilities = ["update"]
}

path "transit/decrypt/orders" {
  capabilities = ["update"]
}
