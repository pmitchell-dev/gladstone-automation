output "network_name" {
  description = "Name of the Docker network shared with DNS services"
  value       = docker_network.dns_net.name
}

output "container_name" {
  description = "Name of the Pi-Hole container"
  value       = docker_container.pihole.name
}
