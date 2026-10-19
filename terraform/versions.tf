terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

# Address and token come from VAULT_ADDR / VAULT_TOKEN (CI uses a short-lived
# token from JWT auth; locally, `vault login -method=oidc`).
provider "vault" {}
