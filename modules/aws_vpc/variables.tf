variable key_name {
    description = "EC2 Key Name"
    type = string
    nullable = true
    default = null
}

variable name {
    description = "Control Plane Name. Controllers are named {host_prefix}-NN.{name}.{dns_zone_name}"
    type = string
    default = "bowtie"
}

variable use_nlb_and_asg {
    type = bool
    default = false
}

variable vpc_id {
    description = "To use an existing VPC, insert it's ID here. For development, testing or other greenfield needs, a created vpc object may be more appropriate"
    type = string
    nullable = true
    default = null
}

variable vpc {
    description = "To have this module own your VPC, place values here instead of using vpc_id"
    type = object({
        vpc_cidr = string
        private_cidr = string
        public_cidr = string
    })
    default = null
    nullable = true
}

variable subnets {
    description = "One object per subnet to deploy one or more controllers into, If names are provided, they take prescedence over `count` and `host_prefix`"
    type = list(object({
        host_prefix = optional(string),
        number_of_controllers = optional(number),
        names = optional(list(string))
        vpc_controller_subnet_id = optional(string),
        vpc_nlb_subnet_id = optional(string),
        site_id = optional(string),
    }))
}

variable dns_zone_name {
    description = "Top Level DNS Zone name e.g example.com"
    type = string
}

variable control_plane_name {
    description = "the name of this control plane"
    default = "bowtie"
}

variable sync_psk {
    description = "Pre Shared Key for synchronizing data between controllers"
}

variable "iam_instance_profile_name" {
    default = null
    nullable = true
    type = string
}

variable "bowtie_sso_config_path" {
  description = "Path to Bowtie/Dex SSO configuration file"
  nullable    = true
  default = null
}

variable "bootstrap_hosts" {
  description = "A List of hosts which all others will try to bootstrap to. This list has special behavior during first-initialization. If you leave this blank, it will only bootstrap to a single VPC module. This is fine for testing or bootstrapping a single site but not multiple regions."
  type = list(string)
  nullable = true
  default = null
}

variable "init-users" {
    sensitive = true
    type = list(object({
        email=string,
        hashed_password=string
    }))
    nullable = true
    default = null
}

variable instance_type {
    type = string
    default = "m5.large"
}

variable operate_route53 {
    description = "If set to false, then you must make your own DNS associations, based on the output `names`"
    type = bool
    default = true
}

variable update_at {
    description = "This object sets the defaults for automatic updates. Follows https://docs.bowtie.works/operating/controller.html#latest-updates"
    type = object({
        OnCalendar=optional(object({
            OnCalendar=string,
            RandomizedDelaySec=optional(string),
            FixedRandomDelay=optional(string),
            OnActiveSec=optional(string)
        }))
    })
    nullable = true
    default = {
        "OnCalendar": {
            "OnCalendar": "11:00",
            "RandomizedDelaySec": "1Hour",
            "FixedRandomDelay": "yes"
            "OnActiveSec": null
        }
    }
}

variable oidc_contents {
    description = "This object replaces bowtie_sso_config_path in order to templatize those values and keep secrets off of your disk. Follows dex's OIDC implementation"
    type = list(object({
        name=string,
        id=string,
        issuer=string,
        clientID=string,
        clientSecret=string,
        //redirectURI=string(default("$DEX_ORIGIN/dex/callback"))
        basicAuthUnsupported=optional(bool)
        insecureSkipEmailVerified=optional(bool)
        insecureEnableGroups=optional(bool)
    }))
    sensitive = true
    nullable = true
    default = null
}

variable allow_public_ssh_from_anywhere {
    description = "If true, enables SSH traffic from the internet, can be used with key_name. For security purposes you should consider an iam_instance_profile instead" 
    type = bool
    default = false
}

variable allow_public_port_80_http_from_anywhere {
    description = "In some cases the Let's Encrypt ACME service will fail and our server will use ZeroSSL as a fallback mechanism. ZeroSSL does not support TLS-ALPN-01 and needs HTTP for bootstrapping."
    default = false
    type = bool
}