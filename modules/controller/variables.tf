variable "bowtie_admin_email" {
  description = "Username for Bowtie API access"
}

variable "bowtie_hashed_password" {
  description = "Hashed password for Bowtie API access"
  sensitive   = true
  type        = string
}

variable "bowtie_sso_config_path" {
  description = "Path to Bowtie/Dex SSO configuration file"
  nullable    = true
}

variable "dns_zone" {
  description = "Route 53 Zone for DNS records"
}

variable "instances" {
  description = "List of Controller instances to create"
}

variable "instance_type" {
  description = "EC2 instance type (size)"
}

variable "key_name" {
  description = "SSH key pair name"
}

variable "all_endpoints" {}

variable "name" {
  description = "Unique deployment name for this org/site"
}

variable "psk" {
  description = "Pre-shared key for cross-Controller clustering"
}

variable "site_id" {
  description = "Site ID"
}

variable "controller_subnet_id" {
  description = "VPC subnet ID for controller deployment"
}

variable "nlb_subnet_id" {
  description = "Optional, set if `use_nlb_and_asg` is setVPC subnet ID for NLB deployment"
  nullable = true
  default = null
}

variable "security_groups" {
  description = "Security groups this instance should be a part of"
}

variable "use_nlb_and_asg" {
  description = "If true, make an ASG with one controller, Make an NLB with a static IP address pointed at the ASG's instance. This can mitigate certain failure modes of AWS Instances"
}

variable "vpc_id" {}

variable "iam_instance_profile_name" {
    default = null
    nullable = true
    type = string
}