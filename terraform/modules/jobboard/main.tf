terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "jobboard" {
  name = "jobboard:latest"
  build {
    context = "${path.root}/../jobboard"
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      for f in try(fileset("${path.root}/../jobboard", "**"), []) : 
      filesha1("${path.root}/../jobboard/${f}")
      if length(regexall("^(\\.git|node_modules)/", f)) == 0
    ]))
  }
}

resource "docker_container" "jobboard" {
  name    = "jobboard"
  image   = docker_image.jobboard.image_id
  restart = "unless-stopped"

  ports {
    internal = 3000
    external = 3001
  }

  volumes {
    host_path      = "/home/gladstone/jobboard/data"
    container_path = "/app/data"
  }

  volumes {
    host_path      = "/home/gladstone/jobboard/cache"
    container_path = "/app/cache"
  }

  env = [
    "NODE_ENV=production",
    "PORT=3000",
    "PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium"
  ]

  security_opts = ["seccomp:unconfined"]
  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}
