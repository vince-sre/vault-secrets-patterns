#!/usr/bin/env bash
# Spin up a throwaway Vault dev server, apply the Terraform config, and check
# that the policies grant what they should and nothing else.
# Requires: vault, terraform, jq. No cloud access needed.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT=${VAULT_DEV_PORT:-18200}
export VAULT_ADDR="http://127.0.0.1:${PORT}"
VAULT_TOKEN="dev-only-root-$(date +%s)"
export VAULT_TOKEN
WORK=$(mktemp -d)
LOG="$WORK/vault.log"

# shellcheck disable=SC2317  # invoked via trap
cleanup() {
  if [[ -n "${VAULT_PID:-}" ]]; then kill "$VAULT_PID" 2>/dev/null || true; fi
  rm -rf "$WORK" terraform/terraform.tfstate terraform/terraform.tfstate.backup
}
trap cleanup EXIT

vault server -dev -dev-root-token-id="$VAULT_TOKEN" -dev-listen-address="127.0.0.1:${PORT}" >"$LOG" 2>&1 &
VAULT_PID=$!
for _ in $(seq 1 30); do
  vault status >/dev/null 2>&1 && break
  sleep 0.5
done
vault status >/dev/null

# Off-cluster, Kubernetes auth needs an explicit CA; a throwaway self-signed one is enough here.
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=test-k8s-ca" \
  -keyout "$WORK/ca.key" -out "$WORK/ca.crt" >/dev/null 2>&1
TF_VAR_kubernetes_ca_cert=$(cat "$WORK/ca.crt")
export TF_VAR_kubernetes_ca_cert

echo "==> terraform apply against dev server"
(
  cd terraform
  terraform init -input=false >/dev/null
  TF_VAR_db_admin_password="dev-only" terraform apply -input=false -auto-approve \
    -var db_verify_connection=false \
    -var audit_file_path="$WORK/audit.log" >/dev/null
)

fail=0
assert_caps() { # token path expected
  local got
  got=$(vault token capabilities "$1" "$2")
  if [[ "$got" == "$3" ]]; then
    echo "ok    $2 -> $got"
  else
    echo "FAIL  $2 -> got '$got', want '$3'"
    fail=1
  fi
}

echo "==> app-orders policy"
APP=$(vault token create -policy=app-orders -ttl=5m -field=token)
assert_caps "$APP" kv/data/apps/orders/config      read
assert_caps "$APP" kv/metadata/apps/orders/config  list
assert_caps "$APP" kv/data/apps/billing/config     deny
assert_caps "$APP" database/creds/orders-app       read
assert_caps "$APP" transit/encrypt/orders          update
assert_caps "$APP" transit/keys/orders             deny
assert_caps "$APP" sys/mounts/kv                   deny

echo "==> ci-deployer policy"
CI=$(vault token create -policy=ci-deployer -ttl=5m -field=token)
assert_caps "$CI" aws/sts/ci-deployer              "read, update"
assert_caps "$CI" kv/data/apps/orders/config       deny

echo "==> platform-admin policy cannot read secret values"
ADM=$(vault token create -policy=platform-admin -ttl=5m -field=token)
assert_caps "$ADM" kv/data/apps/orders/config      deny
assert_caps "$ADM" sys/policies/acl/app-orders     "create, delete, list, read, update"

echo "==> KV v2 enforces check-and-set"
if vault kv put kv/apps/orders/config api_url=https://example.invalid >/dev/null 2>&1; then
  echo "FAIL  write without -cas succeeded"; fail=1
else
  echo "ok    write without -cas rejected"
fi
vault kv put -cas=0 kv/apps/orders/config api_url=https://example.invalid >/dev/null
if VAULT_TOKEN=$APP vault kv get -field=api_url kv/apps/orders/config | grep -q example.invalid; then
  echo "ok    app token reads its own secret"
else
  echo "FAIL  app token cannot read its own secret"; fail=1
fi

echo "==> transit round trip with the app token"
PLAIN=$(printf 'card-ending-4242' | base64)
CT=$(VAULT_TOKEN=$APP vault write -field=ciphertext transit/encrypt/orders plaintext="$PLAIN")
if [[ "$CT" == vault:v1:* ]]; then echo "ok    ciphertext is versioned (${CT:0:20}...)"; else echo "FAIL  ciphertext"; fail=1; fi
OUT=$(VAULT_TOKEN=$APP vault write -field=plaintext transit/decrypt/orders ciphertext="$CT" | base64 -d)
if [[ "$OUT" == "card-ending-4242" ]]; then echo "ok    decrypts to original"; else echo "FAIL  decrypt"; fail=1; fi

echo "==> audit device is recording"
if [[ -s "$WORK/audit.log" ]]; then echo "ok    audit log has $(wc -l <"$WORK/audit.log") entries"; else echo "FAIL  audit log empty"; fail=1; fi

exit "$fail"
