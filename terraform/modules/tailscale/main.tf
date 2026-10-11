terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "tailscale" {
  name = "tailscale/tailscale:latest"
}

resource "docker_container" "tailscale" {
  name         = "tailscale"
  image        = docker_image.tailscale.image_id
  restart      = "unless-stopped"
  network_mode = "host"

  capabilities {
    add = ["NET_ADMIN", "NET_RAW"]
  }

  devices {
    host_path      = "/dev/net/tun"
    container_path = "/dev/net/tun"
  }

  volumes {
    host_path      = "/home/gladstone/tailscale/state"
    container_path = "/var/lib/tailscale"
  }

  env = [
    "TS_STATE_DIR=/var/lib/tailscale",
    "TS_USERSPACE=false",
    "TS_AUTHKEY=${var.authkey}",
    "TS_EXTRA_ARGS=--hostname=${var.hostname} --advertise-routes=${var.advertise_routes} --advertise-exit-node --accept-routes"
  ]
}
