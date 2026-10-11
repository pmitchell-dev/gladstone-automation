terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "nginx_dot" {
  name = "nginx:alpine"
}

resource "docker_container" "dot_proxy" {
  name    = "dot-proxy"
  image   = docker_image.nginx_dot.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = var.dns_network_name
  }

  ports {
    internal = 853
    external = var.dot_port
    protocol = "tcp"
  }

  volumes {
    host_path      = "/home/gladstone/dot-proxy/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
    read_only      = true
  }

  volumes {
    host_path      = "/etc/letsencrypt"
    container_path = "/etc/letsencrypt"
    read_only      = true
  }
}
