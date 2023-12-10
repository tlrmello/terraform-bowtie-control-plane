variable "instance_type" {
  description = "Instance size for OS instance"
  type        = string
  default     = "m5.large"
}

variable "dns_zone_name" {
  description = "Existing DNS zone to create Controller names under"
}

variable "name" {
  description = "Unique deployment name for this org, used as a domain part"
  default = "bowtie"
}

variable "org_name" {
  description = "Human facing org name. This shows up in user-facing UI and NIC names are derived from this."
}

variable "key_name" {
  description = "Key Name"
  type        = string
  nullable = true
  default = null
}

variable "bowtie_admin_email" {
  description = "Username for Bowtie API access"
}

variable "bowtie_password" {
  description = "Cleartext password for Bowtie API access"
  sensitive   = true
  type        = string
  nullable = true
  default = null
}

variable "bowtie_name" {
  description = "Human-readable name for Bowtie user"
  default = "bowtie"
  type = string
}

variable "bowtie_sso_config_path" {
  description = "Path to Bowtie/Dex SSO configuration file"
  nullable    = true
  default     = null
}

variable "aws-sa-east-1" {
    default = []
    type = list(object({
        vpc_id = string,
        subnets = list(object({
          host_prefix = string,
          vpc_controller_subnet_id = string,
          vpc_nlb_subnet_id = optional(string),
          number_of_controllers = number,
        }))
    }))
}

variable "aws-us-east-1" {
    default = []
    type = list(object({
        vpc_id = string,
        subnets = list(object({
          host_prefix = string,
          vpc_controller_subnet_id = string,
          vpc_nlb_subnet_id = optional(string),
          number_of_controllers = number,
        }))
    }))
}

variable "aws-us-east-2" {
    default = []
    type = list(object({
        vpc_id = string,
        subnets = list(object({
          host_prefix = string,
          vpc_controller_subnet_id = string,
          vpc_nlb_subnet_id = optional(string),
          number_of_controllers = number,
        }))
    }))
}

variable "aws-us-west-1" {
    default = []
    type = list(object({
        vpc_id = string,
        subnets = list(object({
          host_prefix = string,
          vpc_controller_subnet_id = string,
          vpc_nlb_subnet_id = optional(string),
          number_of_controllers = number,
        }))
    }))
}

variable "aws-us-west-2" {
    default = []
    type = list(object({
        vpc_id = string,
        subnets = list(object({
          host_prefix = string,
          vpc_controller_subnet_id = string,
          vpc_nlb_subnet_id = optional(string),
          number_of_controllers = number,
        }))
    }))
}

variable "use_nlb_and_asg" {
  description = "Use an ASG (with membership = 1) and an NLB for each controller."
  default = false
  type = bool
}


variable "iam_instance_profile_name" {
    default = null
    nullable = true
    type = string
}


variable "dns_block_lists" {
    type = list(object({
        id = string, // UUID
        upstream = string, // URL, Mutually exclusive with contents
        contents = string, // Mutually exclusive with Upstream
        override_to_allow = string,
    }))

    default = [
        {
            "id": "6a229d95-9977-48b6-8fde-bc05769320f9",
            "name": "Threat Intelligence Feed",
            "upstream": "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/tif.txt",
            "contents": "",
            "override_to_allow": "",
        }
    ]
}


variable "extra_bowtie_arguments" {
    type = map(string)
    default = {
        BOWTIE_JOIN_STRATEGY = "bootstrap-at-failure"
    }
}
