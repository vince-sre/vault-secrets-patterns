# CI pipelines: short-lived AWS credentials for deploys, plus read access to
# deploy-time config. No access to application secrets.
path "aws/sts/ci-deployer" {
  capabilities = ["read", "update"]
}

path "kv/data/ci/*" {
  capabilities = ["read"]
}
