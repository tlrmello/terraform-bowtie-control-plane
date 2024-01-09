variable "control_plane_name" {
  type = string
  description = "The subdomain under which controllers will obtain hostnames. If a dns_zone_name is given as 'example.com', and if this variable is the default of 'bowtie', the resulting base zone for controller host names will be 'bowtie.example.com'."
  default = "bowtie"
}

variable "dns_zone_name" {
  type = string
  description = "The base DNS zone for the cluster deployment. A subdomain, under the variable 'control_plane_name' will be added to this base zone in constructing controller fully qualified host names."
  default = "example.com"
}

variable bowtie_admin_email {
  type = string
  description = "Bowtie initial administrative user's email address that will pre-seed the controller."
  default = "admin@example.com"
}
