output "container_name" {
  description = "Name of the Tailscale container"
  value       = docker_container.tailscale.name
}

output "container_id" {
  description = "ID of the Tailscale container"
  value       = docker_container.tailscale.id
}
