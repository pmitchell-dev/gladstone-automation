terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "nginx" {
  name = "nginx:alpine"
}

resource "docker_container" "portfolio" {
  name    = "portfolio"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = 8080
  }

  volumes {
    host_path      = "/home/gladstone/pmitchell-dev.github.io"
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }
}
