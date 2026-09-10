terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_network" "relayit_net" {
  name = "relayit_network"
}

# Postgres Database
resource "docker_image" "postgres" {
  name = "postgres:16"
}

resource "docker_container" "db" {
  name    = "relayit-db"
  image   = docker_image.postgres.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.relayit_net.name
  }

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=relayit"
  ]

  volumes {
    host_path      = "/home/gladstone/relayit/data/pgdata"
    container_path = "/var/lib/postgresql/data"
  }
}

# RelayIT Web
resource "docker_image" "relayit_web" {
  name = "relayit-web:latest"
  build {
    context = "/home/gladstone/relayit"
  }
}

resource "docker_container" "web" {
  name    = "relayit-web"
  image   = docker_image.relayit_web.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.relayit_net.name
  }

  env = [
    "PYTHONPATH=/app",
    "DATABASE_URL=postgresql://postgres:${var.db_password}@relayit-db:5432/relayit",
    "SECRET_KEY=change_this_to_a_secure_random_string"
  ]

  volumes {
    host_path      = "/home/gladstone/relayit/app"
    container_path = "/app/app"
  }
}

# Caddy
resource "docker_image" "caddy" {
  name = "caddy:2-alpine"
}

resource "docker_container" "caddy" {
  name    = "relayit-caddy"
  image   = docker_image.caddy.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.relayit_net.name
  }

  ports {
    internal = 80
    external = 80
  }

  volumes {
    host_path      = "/home/gladstone/relayit/Caddyfile"
    container_path = "/etc/caddy/Caddyfile"
  }
  volumes {
    host_path      = "/home/gladstone/relayit/data/caddy_data"
    container_path = "/data"
  }
  volumes {
    host_path      = "/home/gladstone/relayit/data/caddy_config"
    container_path = "/config"
  }
}
