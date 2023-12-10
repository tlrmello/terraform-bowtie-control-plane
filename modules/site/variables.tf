variable "bowtie_admin_email" {
  description = "Username for Bowtie API access"
}

variable bowtie_hashed_password {}

variable "bowtie_sso_config_path" {
  description = "Path to Bowtie/Dex SSO configuration file"
  nullable    = true
}

variable "dns_zone" {
  description = "Route 53 Zone for DNS records"
}

variable "instances" {
  description = "Map of instances within each zone"
}

variable "instance_type" {
  description = "Instance type (size)"
}

variable "name" {
  description = "Unique deployment name for this org/site"
}

variable "psk" {
  description = "Pre-shared key for cross-Controller clustering"
}

variable "key_name" {
  description = "ssh key file name"
}


variable "all_endpoints" {}

variable "vpc_id" {}

variable "vpc_nlb_subnet_id" {
    description = "Optional, set if `use_nlb_and_asg` is setVPC subnet ID for NLB deployment"
    nullable = true
    default = null
}
variable "vpc_controller_subnet_id" {
    description = "VPC subnet ID for controller deployment"
}

variable "subnets" {
  type = list(object({
    cidr = string,
  }))
  nullable = true
  default = null
}

variable "use_nlb_and_asg" {}

variable "iam_instance_profile_name" {
    default = null
    nullable = true
    type = string
}