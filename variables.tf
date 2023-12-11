variable "instance_type" {
  description = "Instance size for OS instance"
  type        = string
  default     = "m5.large"
}

variable "name" {
  description = "Unique deployment name for this org, used as a domain part"
  default = "bowtie"
}

variable "org_name" {
  description = "Human facing org name. This shows up in user-facing UI and NIC names are derived from this."
}

variable "bowtie_sso_config_path" {
  description = "Path to Bowtie/Dex SSO configuration file"
  nullable    = true
  default     = null
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

variable "api_hostname" {
    type = string
}

variable "extra_bowtie_arguments" {
    type = map(string)
    default = {
        BOWTIE_JOIN_STRATEGY = "bootstrap-at-failure"
    }
}
