terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "homeasset" {
  name = "homeasset:latest"
  build {
    context = pathexpand("~/homeasset")
  }
}

resource "docker_container" "homeasset" {
  name    = "homeasset"
  image   = docker_image.homeasset.name
  restart = "unless-stopped"

  ports {
    internal = 8000
    external = 7745
  }

  volumes {
    host_path      = pathexpand("~/homeasset/data")
    container_path = "/data"
  }

  env = [
    "LOG_LEVEL=info",
    "DATABASE_URL=sqlite:////data/homeasset.db",
    "UPLOAD_DIR=/data/uploads",
    "DOC_DIR=/data/documents"
  ]
}
