terraform { required_providers { docker = { source = "kreuzwerker/docker" } } }
resource "docker_container" "immich_server" { name = "immich_server"; image = "ghcr.io/immich-app/immich-server:release" }
