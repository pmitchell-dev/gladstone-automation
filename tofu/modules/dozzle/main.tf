terraform { required_providers { docker = { source = "kreuzwerker/docker" } } }
resource "docker_container" "dozzle" { name = "dozzle"; image = "amir20/dozzle:latest" }
