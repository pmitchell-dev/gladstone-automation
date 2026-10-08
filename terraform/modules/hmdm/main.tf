terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

resource "docker_image" "hmdm" {
  name = "headwindmdm/hmdm:local"
  build {
    context = "${path.module}/src"
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      for f in try(fileset("${path.module}/src", "**"), []) : 
      filesha1("${path.module}/src/${f}")
      if length(regexall("^(\\.git)/", f)) == 0
    ]))
  }
}

resource "docker_container" "postgresql" {
  name    = "hmdm-postgresql"
  image   = "postgres:12-alpine"
  restart = "unless-stopped"

  env = [
    "POSTGRES_USER=${var.sql_user}",
    "POSTGRES_PASSWORD=${var.sql_pass}",
    "POSTGRES_DB=${var.sql_base}"
  ]

  volumes {
    host_path      = "/home/gladstone/hmdm/volumes/db"
    container_path = "/var/lib/postgresql/data"
  }
}

resource "docker_container" "hmdm" {
  name    = "hmdm"
  image   = docker_image.hmdm.image_id
  restart = "unless-stopped"
  depends_on = [docker_container.postgresql]

  ports {
    internal = 8080
    external = 8085
  }
  ports {
    internal = 8443
    external = 8443
  }
  ports {
    internal = 31000
    external = 31000
  }

  volumes {
    host_path      = "/home/gladstone/hmdm/volumes/work"
    container_path = "/usr/local/tomcat/work"
  }
  volumes {
    host_path      = "/home/gladstone/hmdm/volumes/hmdm-config"
    container_path = "/usr/local/tomcat/conf/Catalina/localhost"
  }
  volumes {
    host_path      = "/home/gladstone/hmdm/volumes/webapps"
    container_path = "/usr/local/tomcat/webapps"
  }
  volumes {
    host_path      = "/home/gladstone/hmdm/volumes/letsencrypt"
    container_path = "/etc/letsencrypt"
  }

  env = [
    "SQL_HOST=hmdm-postgresql",
    "SQL_USER=${var.sql_user}",
    "SQL_BASE=${var.sql_base}",
    "SQL_PASS=${var.sql_pass}",
    "BASE_DOMAIN=${var.base_domain}",
    "PROTOCOL=${var.protocol}",
    "ADMIN_EMAIL=${var.admin_email}",
    "SHARED_SECRET=${var.shared_secret}",
    "HTTPS_LETSENCRYPT=${var.https_letsencrypt}",
    "FORCE_RECONFIGURE=${var.force_reconfigure}"
  ]
}
