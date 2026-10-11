variable "web_port" {
  description = "Host port for Pi-hole web admin dashboard"
  type        = number
  default     = 8053
}

variable "admin_password" {
  description = "Password to access Pi-hole web interface (leave blank for random or no password initially)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "timezone" {
  description = "Timezone for Pi-hole logs and statistics"
  type        = string
  default     = "America/Chicago"
}

variable "virtual_host" {
  description = "Authorized virtual host header for Cloudflare access"
  type        = string
  default     = "ads.localrepo.net"
}

variable "upstream_dns" {
  description = "Primary and secondary upstream DNS resolvers"
  type        = string
  default     = "1.1.1.1;1.0.0.1"
}
