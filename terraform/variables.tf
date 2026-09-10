variable "vault_address" {
  description = "Address of the local Vault dev server"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault token for accessing secrets"
  type        = string
  sensitive   = true
}

# The following blocks instruct Tofu to read secrets from Vault
provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

data "vault_generic_secret" "gemini_api" {
  path = "secret/gemini"
}

data "vault_generic_secret" "postgres" {
  path = "secret/postgres"
}
