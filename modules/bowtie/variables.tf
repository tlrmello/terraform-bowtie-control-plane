variable "dns_zone" {
  description = "Route 53 Zone for DNS records"
}

variable "endpoint" {
  description = "TLS-secured Bowtie Control Plane endpoint"
}

variable "username" {
  description = "Bowtie username (usually email address)"
}

variable "password" {
  description = "Bowtie password"
}

variable "name" {
  description = "Human-readable name for the Bowtie user"
}

variable "org_name" {
  description = "Human facing org name. This shows up in user-facing UI and NIC names are derived from this."
}

variable "sites" {
  description = "Map of sites to configure"
  type        = map(any)
}
