terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.19.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Modules for container stacks
module "relayit" {
  source = "./modules/relayit"
  db_password = data.vault_generic_secret.postgres.data["password"]
}

module "homeasset" {
  source = "./modules/homeasset"
  db_password = data.vault_generic_secret.postgres.data["password"]
}

module "jobboard" {
  source = "./modules/jobboard"
}

module "gemini" {
  source = "./modules/gemini"
  api_key = data.vault_generic_secret.gemini_api.data["key"]
}

module "rustdesk" {
  source = "./modules/rustdesk"
}

module "dozzle" {
  source = "./modules/dozzle"
}

module "immich" {
  source = "./modules/immich"
  db_password = data.vault_generic_secret.postgres.data["password"]
}
