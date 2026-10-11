variable "dns_network_name" {
  description = "Name of the shared Docker network to communicate with Pi-Hole"
  type        = string
}

variable "dot_port" {
  description = "Host port for DNS over TLS"
  type        = number
  default     = 853
}

variable "cert_domain" {
  description = "Domain name for the Let's Encrypt certificate"
  type        = string
  default     = "dns.localrepo.net"
}
