variable "org_name" {
  description = "Human facing org name. This shows up in user-facing UI and NIC names are derived from this."
}

variable "sites" {
  description = "Map of sites to configure"
  type        = map(any)
  nullable = true
  default = {}
}
