terraform { required_providers { docker = { source = "kreuzwerker/docker" } } }
resource "docker_container" "relayit_web" { name = "relayit-web"; image = "relayit:latest" }
