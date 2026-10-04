terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "piccurator" {
  name = "piccurator:latest"
  build {
    context = "${path.root}/../piccurator"
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      for f in try(fileset("${path.root}/../piccurator", "**"), []) : 
      filesha1("${path.root}/../piccurator/${f}")
      if length(regexall("^(\\.git|node_modules|venv|\\.venv|__pycache__)/", f)) == 0
    ]))
  }
}

resource "docker_container" "piccurator" {
  name    = "piccurator"
  image   = docker_image.piccurator.image_id
  restart = "unless-stopped"

  ports {
    internal = 8000
    external = 8000
  }

  volumes {
    host_path      = "/mnt/backups/family_photos"
    container_path = "/mnt/backups/family_photos"
  }

  env = [
    "TZ=America/Chicago"
  ]
}
