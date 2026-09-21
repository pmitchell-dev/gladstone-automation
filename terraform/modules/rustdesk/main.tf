terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "rustdesk" {
  name = "rustdesk/rustdesk-server:latest"
}

resource "docker_container" "hbbr" {
  name    = "hbbr"
  image   = docker_image.rustdesk.name
  command = ["hbbr"]
  restart = "always"

  network_mode = "host"

  volumes {
    host_path      = "/home/gladstone/rustdesk/data"
    container_path = "/root"
  }
}

resource "docker_container" "hbbs" {
  name    = "hbbs"
  image   = docker_image.rustdesk.name
  command = ["hbbs", "-r", "rustdesk.dark-ops.cc"]
  restart = "always"

  network_mode = "host"

  volumes {
    host_path      = "/home/gladstone/rustdesk/data"
    container_path = "/root"
  }

  depends_on = [
    docker_container.hbbr
  ]
}
