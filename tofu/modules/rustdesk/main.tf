terraform { required_providers { docker = { source = "kreuzwerker/docker" } } }
resource "docker_container" "hbbs" { name = "hbbs"; image = "rustdesk/rustdesk-server:latest" }
