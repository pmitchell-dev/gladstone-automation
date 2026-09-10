terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_network" "dozzle_net" {
  name = "dozzle_network"
}

# Dozzle Main Instance
resource "docker_image" "dozzle" {
  name = "amir20/dozzle:latest"
}

resource "docker_container" "dozzle" {
  name    = "dozzle"
  image   = docker_image.dozzle.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.dozzle_net.name
  }

  ports {
    internal = 8080
    external = 8888
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  env = [
    "DOZZLE_HOSTNAME=Webhost (192.168.50.217)",
    "DOZZLE_REMOTE_AGENT=192.168.50.138:7007"
  ]
}

# Webhost Scripts Log Bridge
resource "docker_image" "debian_slim" {
  name = "debian:bookworm-slim"
}

resource "docker_container" "webhost_scripts_log" {
  name    = "webhost-scripts-log"
  image   = docker_image.debian_slim.name
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.dozzle_net.name
  }

  volumes {
    host_path      = "/home/gladstone/scripts/logs"
    container_path = "/logs"
  }

  entrypoint = [
    "bash", "-c", 
    "mkdir -p /logs && touch /logs/rebuild.log /logs/services_manager.log /logs/backup.log && echo '📋 [Webhost] Script log stream starting...' && tail -f /logs/rebuild.log /logs/services_manager.log /logs/backup.log"
  ]

  labels {
    label = "dozzle.name"
    value = "Webhost Scripts"
  }
}

# NVR Syslog Receiver
resource "docker_image" "python_slim" {
  name = "python:3.11-slim"
}

resource "docker_container" "nvr_syslog" {
  name    = "nvr-syslog"
  image   = docker_image.python_slim.name
  restart = "unless-stopped"
  
  network_mode = "host"

  volumes {
    host_path      = "/home/gladstone/scripts/nvr_syslog.py"
    container_path = "/nvr_syslog.py"
    read_only      = true
  }

  entrypoint = ["python3", "-u", "/nvr_syslog.py"]

  labels {
    label = "dozzle.name"
    value = "ANNKE NVR Syslog"
  }
}
