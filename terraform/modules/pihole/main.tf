terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

resource "docker_network" "dns_net" {
  name = "dns_network"
}

resource "docker_image" "pihole" {
  name = "pihole/pihole:latest"
}

resource "docker_container" "pihole" {
  name    = "pihole"
  image   = docker_image.pihole.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.dns_net.name
  }

  capabilities {
    add = ["NET_ADMIN"]
  }

  # DNS Ports
  ports {
    internal = 53
    external = 53
    protocol = "tcp"
  }

  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }

  # Web Admin Dashboard Port
  ports {
    internal = 80
    external = var.web_port
    protocol = "tcp"
  }

  # Persistent Configuration Volumes
  volumes {
    host_path      = "/home/gladstone/pihole/etc-pihole"
    container_path = "/etc/pihole"
  }

  volumes {
    host_path      = "/home/gladstone/pihole/etc-dnsmasq.d"
    container_path = "/etc/dnsmasq.d"
  }

  env = [
    "TZ=${var.timezone}",
    "WEBPASSWORD=${var.admin_password}",
    "FTLCONF_LOCAL_IPV4=192.168.50.217",
    "FTLCONF_dns_listeningMode=ALL",
    "VIRTUAL_HOST=${var.virtual_host}",
    "PIHOLE_DNS_=${var.upstream_dns}"
  ]
}
