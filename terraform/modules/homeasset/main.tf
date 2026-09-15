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
    context = "${path.root}/../homeasset"
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      for f in try(fileset("${path.root}/../homeasset", "**"), []) : 
      filesha1("${path.root}/../homeasset/${f}")
      if length(regexall("^(\\.git|node_modules|venv|\\.venv)/", f)) == 0
    ]))
  }
}

resource "docker_container" "homeasset" {
  name    = "homeasset"
  image   = docker_image.homeasset.image_id
  restart = "unless-stopped"

  ports {
    internal = 8000
    external = 7745
  }

  volumes {
    host_path      = "/home/gladstone/homeasset/data"
    container_path = "/data"
  }

  env = [
    "LOG_LEVEL=info",
    "DATABASE_URL=sqlite:////data/homeasset.db",
    "UPLOAD_DIR=/data/uploads",
    "DOC_DIR=/data/documents"
  ]
}
