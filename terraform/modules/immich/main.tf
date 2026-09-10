terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_network" "immich_net" {
  name = "immich_network"
}

# Redis
resource "docker_image" "redis" {
  name = "docker.io/valkey/valkey:9@sha256:8e8d64b405ce18f41b8e5ee20aa4687a8ed0022d1298f2ce31cdcf3a76e09411"
}

resource "docker_container" "redis" {
  name    = "immich_redis"
  image   = docker_image.redis.name
  restart = "always"

  networks_advanced {
    name = docker_network.immich_net.name
  }
}

# Postgres Database
resource "docker_image" "postgres" {
  name = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23"
}

resource "docker_volume" "pgdata" {
  name = "immich_pgdata"
}

resource "docker_container" "database" {
  name    = "immich_postgres"
  image   = docker_image.postgres.name
  restart = "always"
  shm_size = 134217728 # 128MB

  networks_advanced {
    name = docker_network.immich_net.name
  }

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=immich",
    "POSTGRES_INITDB_ARGS=--data-checksums"
  ]

  volumes {
    volume_name    = docker_volume.pgdata.name
    container_path = "/var/lib/postgresql/data"
  }
}

# Immich Server
resource "docker_image" "immich_server" {
  name = "ghcr.io/immich-app/immich-server:release"
}

resource "docker_container" "immich_server" {
  name    = "immich_server"
  image   = docker_image.immich_server.name
  restart = "always"

  networks_advanced {
    name = docker_network.immich_net.name
  }

  ports {
    internal = 2283
    external = 2283
  }

  env = [
    "DB_PASSWORD=${var.db_password}",
    "DB_USERNAME=postgres",
    "DB_DATABASE_NAME=immich",
    "DB_HOSTNAME=immich_postgres",
    "REDIS_HOSTNAME=immich_redis"
  ]

  volumes {
    host_path      = "/mnt/backups/immich_uploads"
    container_path = "/data"
  }
  
  volumes {
    host_path      = "/etc/localtime"
    container_path = "/etc/localtime"
    read_only      = true
  }

  volumes {
    host_path      = "/mnt/backups/family_photos"
    container_path = "/mnt/backups/family_photos"
    read_only      = true
  }
}
