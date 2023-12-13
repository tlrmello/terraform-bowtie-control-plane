variable "control_plane_name" {
  type = string
  description = "The subdomain under which controllers will obtain hostnames. If a dns_zone_name is given as 'example.com', and if this variable is the default of 'bowtie', the resulting base zone for controller host names will be 'bowtie.example.com'."
  default = "bowtie"
}

variable "dns_zone_name" {
  type = string
  description = "The base DNS zone for the cluster deployment. A subdomain, under the variable 'control_plane_name' will be added to this base zone in constructing controller fully qualified host names."
  default = "r.bowtie.work.example"
}

variable bootstrap_hosts {
  type = list(string)
  description = "When deploying a high availability Bowtie installation, the controllers must know one another's fully qualified host names to form a cluster. This list contains the initial fully qualified controller host names, comprised of host_prefix##.control_plane_name.dns_zone_name where ## is the count of controllers deployed starting with 00."
  default = [
    "east-00.bowtie.r.bowtie.work.example",
    "east-01.bowtie.r.bowtie.work.example",
    "west-a-00.bowtie.r.bowtie.work.example",
    "west-b-00.bowtie.r.bowtie.work.example",
  ]
}

variable bowtie_admin_email {
  type = string
  description = "Bowtie initial administrative user's email address that will pre-seed the controller."
  default = "william@bowtie.works"
}

variable bowtie_sync_psk {
  type = string
  sensitive=true
  description = "The shared passkey is utilized to authorize data replication between controller instances. This value is secret and should be handled with care."
  default = null
}

variable bowtie_admin_password{
    default = "A Pretty Dec password is randomab4582a6ac34e6213edc"
}