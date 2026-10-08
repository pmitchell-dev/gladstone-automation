variable "sql_user" {
  type    = string
  default = "hmdm"
}

variable "sql_pass" {
  type    = string
  default = "Ch@nGeMe_HMDM"
}

variable "sql_base" {
  type    = string
  default = "hmdm"
}

variable "base_domain" {
  type    = string
  default = "mdm.localrepo.net"
}

variable "protocol" {
  type    = string
  default = "http"
  description = "Use http if SSL is terminated by Cloudflare and you want local unencrypted traffic, otherwise https"
}

variable "admin_email" {
  type    = string
  default = "admin@localrepo.net"
}

variable "shared_secret" {
  type    = string
  default = "changeme-C3z9vi54"
}

variable "https_letsencrypt" {
  type    = string
  default = "false"
  description = "Set to true to use internal letsencrypt logic, false to disable it if using Cloudflare Tunnels"
}

variable "force_reconfigure" {
  type    = string
  default = "true"
  description = "Set to 'true' to force hmdm to re-run configuration scripts"
}
