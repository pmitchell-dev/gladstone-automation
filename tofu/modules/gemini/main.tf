terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

# Image build from local directory
resource "docker_image" "gemini_api" {
  name = "gemini-api:latest"
  build {
    context    = pathexpand("~/gemini-api")
    dockerfile = "Dockerfile.gemini"
  }
}

# Container deployment using Vault injected secret
resource "docker_container" "gemini_api" {
  name  = "gemini-api"
  image = docker_image.gemini_api.name
  restart = "unless-stopped"

  ports {
    internal = 5050
    external = 5050
  }

  env = [
    "PYTHONUNBUFFERED=1",
    "GEMINI_API_KEY=${var.api_key}",
    "GEMINI_DEFAULT_MODEL=gemini-3.1-flash-lite",
    "GEMINI_FALLBACK_MODEL=gemini-2.5-flash",
    "GEMINI_MAX_RETRIES=5"
  ]
}
