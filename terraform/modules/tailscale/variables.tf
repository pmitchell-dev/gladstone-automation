variable "authkey" {
  description = "Tailscale pre-authenticated auth key"
  type        = string
  sensitive   = true
}

variable "hostname" {
  description = "Hostname for the Tailscale node in MagicDNS"
  type        = string
  default     = "gladstone-webhost"
}

variable "advertise_routes" {
  description = "Local subnet routes to advertise to the tailnet"
  type        = string
  default     = "192.168.50.0/24"
}
