#
# Example code for building a complete private network gated by access
# via Bowtie.
#
# There are some nuances around using this code, you should consult
# the "Terraform" section in ./README.md to get started.
#

terraform {
  required_providers {
    bowtie = {
      source  = "bowtieworks/bowtie"
      version = "0.4"
    }
    checkmate = {
      source = "tetratelabs/checkmate"
      version = "1.5.0"
    }
  }
}


locals {
  aws-sa-east-1-flattened = flatten([
    for i in range(0, length(var.aws-sa-east-1)) : [
      for j in range(0, length(var.aws-sa-east-1[i].subnets)) : [
        for k in range(0, var.aws-sa-east-1[i].subnets[j].number_of_controllers) : {
          name = format("%s%02d", var.aws-sa-east-1[i].subnets[j].host_prefix, k)
          vpc_id = var.aws-sa-east-1[i].vpc_id
          vpc_controller_subnet_id = var.aws-sa-east-1[i].subnets[j].vpc_controller_subnet_id
          vpc_nlb_subnet_id = var.aws-sa-east-1[i].subnets[j].vpc_nlb_subnet_id
        }
      ]
    ]
  ])
  aws-sa-east-1-hosts = [for i in range(0, length(local.aws-sa-east-1-flattened)) : local.aws-sa-east-1-flattened[i].name]
  

  aws-us-east-1-flattened = flatten([
    for i in range(0, length(var.aws-us-east-1)) : [
      for j in range(0, length(var.aws-us-east-1[i].subnets)) : [
        for k in range(0, var.aws-us-east-1[i].subnets[j].number_of_controllers) : {
          name = format("%s%02d", var.aws-us-east-1[i].subnets[j].host_prefix, k)
          vpc_id = var.aws-us-east-1[i].vpc_id
          vpc_controller_subnet_id = var.aws-us-east-1[i].subnets[j].vpc_controller_subnet_id
          vpc_nlb_subnet_id = var.aws-us-east-1[i].subnets[j].vpc_nlb_subnet_id
        }
      ]
    ]
  ])
  aws-us-east-1-hosts = [for i in range(0, length(local.aws-us-east-1-flattened)) : local.aws-us-east-1-flattened[i].name]
  
  aws-us-east-2-flattened = flatten([
    for i in range(0, length(var.aws-us-east-2)) : [
      for j in range(0, length(var.aws-us-east-2[i].subnets)) : [
        for k in range(0, var.aws-us-east-2[i].subnets[j].number_of_controllers) : {
          name = format("%s%02d", var.aws-us-east-2[i].subnets[j].host_prefix, k)
          vpc_id = var.aws-us-east-2[i].vpc_id
          vpc_controller_subnet_id = var.aws-us-east-2[i].subnets[j].vpc_controller_subnet_id
          vpc_nlb_subnet_id = var.aws-us-east-2[i].subnets[j].vpc_nlb_subnet_id
        }
      ]
    ]
  ])
  aws-us-east-2-hosts = [for i in range(0, length(local.aws-us-east-2-flattened)) : local.aws-us-east-2-flattened[i].name]
  

  aws-us-west-1-flattened = flatten([
    for i in range(0, length(var.aws-us-west-1)) : [
      for j in range(0, length(var.aws-us-west-1[i].subnets)) : [
        for k in range(0, var.aws-us-west-1[i].subnets[j].number_of_controllers) : {
          name = format("%s%02d", var.aws-us-west-1[i].subnets[j].host_prefix, k)
          vpc_id = var.aws-us-west-1[i].vpc_id
          vpc_controller_subnet_id = var.aws-us-west-1[i].subnets[j].vpc_controller_subnet_id
          vpc_nlb_subnet_id = var.aws-us-west-1[i].subnets[j].vpc_nlb_subnet_id
        }
      ]
    ]
  ])
  aws-us-west-1-hosts = [for i in range(0, length(local.aws-us-west-1-flattened)) : local.aws-us-west-1-flattened[i].name]
  
  aws-us-west-2-flattened = flatten([
    for i in range(0, length(var.aws-us-west-2)) : [
      for j in range(0, length(var.aws-us-west-2[i].subnets)) : [
        for k in range(0, var.aws-us-west-2[i].subnets[j].number_of_controllers) : {
          name = format("%s%02d", var.aws-us-west-2[i].subnets[j].host_prefix, k)
          vpc_id = var.aws-us-west-2[i].vpc_id
          vpc_controller_subnet_id = var.aws-us-west-2[i].subnets[j].vpc_controller_subnet_id
          vpc_nlb_subnet_id = var.aws-us-west-2[i].subnets[j].vpc_nlb_subnet_id
        }
      ]
    ]
  ])
  aws-us-west-2-hosts = [for i in range(0, length(local.aws-us-west-2-flattened)) : local.aws-us-west-2-flattened[i].name]
  
  all_hosts = concat(
    flatten(local.aws-sa-east-1-hosts),
    flatten(local.aws-us-east-1-hosts),
    flatten(local.aws-us-east-2-hosts),
    flatten(local.aws-us-west-1-hosts),
    flatten(local.aws-us-west-2-hosts),
  )

  aws-sa-east-1-endpoints = [for host in flatten(local.aws-sa-east-1-flattened) : "https://${host.name}.${var.name}.${data.aws_route53_zone.org.name}"]
  aws-us-east-1-endpoints = [for host in flatten(local.aws-us-east-1-flattened) : "https://${host.name}.${var.name}.${data.aws_route53_zone.org.name}"]
  aws-us-east-2-endpoints = [for host in flatten(local.aws-us-east-2-flattened) : "https://${host.name}.${var.name}.${data.aws_route53_zone.org.name}"]
  aws-us-west-1-endpoints = [for host in local.aws-us-west-1-hosts : "https://${host}.${var.name}.${data.aws_route53_zone.org.name}"]
  aws-us-west-2-endpoints = [for host in local.aws-us-west-2-hosts : "https://${host}.${var.name}.${data.aws_route53_zone.org.name}"]
  
  all_endpoints       = concat(
    local.aws-sa-east-1-endpoints,
    local.aws-us-east-1-endpoints,
    local.aws-us-east-2-endpoints,
    local.aws-us-west-1-endpoints,
    local.aws-us-west-2-endpoints,
  )

  bowtie_endpoint = local.all_endpoints[0]

  //bowtie_password = coalesce(var.bowtie_password, random_password.GENERATED_PASSWORD.result)
}


provider "aws" {
  region = "sa-east-1"
  alias  = "sa-east-1"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.name} cluster"
    }
  }
}
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.name} cluster"
    }
  }
}
provider "aws" {
  region = "us-east-2"
  alias  = "us-east-2"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.name} cluster"
    }
  }
}

provider "aws" {
  region = "us-west-1"
  alias  = "us-west-1"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.name} cluster"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  alias  = "us-west-2"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.name} cluster"
    }
  }
}

data "aws_route53_zone" "org" {
  name         = var.dns_zone_name
  private_zone = false
  provider     = aws.us-east-2
}

resource "random_uuid" "bowtie_psk" {}

resource "checkmate_http_health" "baseline_up" {
  # This is the url of the endpoint we want to check
  url = "${local.bowtie_endpoint}/-net/api/v0/ok"

  # Will perform an HTTP GET request
  method = "GET"

  # The overall test should not take longer than 30 minutes
  timeout = 1000 * 60 * 30 # ms, seconds, minutes

  # Wait 0.5 seconds between attempts
  interval = 500

  # Expect a status 200 OK
  status_code = 200

  # We want 2 successes in a row
  consecutive_successes = 2
}

// Copy and paste for all required regions
module "site-aws-sa-east-1" {
  count = length(local.aws-sa-east-1-flattened)
  source                 = "./modules/site"
  dns_zone               = data.aws_route53_zone.org
  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_password))
  bowtie_sso_config_path = var.bowtie_sso_config_path
  providers              = { aws = aws.sa-east-1 }
  instances = {
    "public" = {
      "subnet" = 100,
      "hosts"  = local.aws-sa-east-1-hosts
    },
  }
  iam_instance_profile_name = var.iam_instance_profile_name
  all_endpoints = local.all_endpoints
  vpc_id        = local.aws-sa-east-1-flattened[count.index].vpc_id
  vpc_nlb_subnet_id = local.aws-sa-east-1-flattened[count.index].vpc_nlb_subnet_id
  vpc_controller_subnet_id = local.aws-sa-east-1-flattened[count.index].vpc_controller_subnet_id
  use_nlb_and_asg       = var.use_nlb_and_asg
  instance_type = var.instance_type
  name          = var.name
  psk           = random_uuid.bowtie_psk
  key_name    = var.key_name
  subnets = null
}

module "site-aws-us-east-1" {
  count = length(local.aws-us-east-1-flattened)
  source                 = "./modules/site"
  dns_zone               = data.aws_route53_zone.org
  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_password))
  bowtie_sso_config_path = var.bowtie_sso_config_path
  providers              = { aws = aws.us-east-1 }
  instances = {
    "public" = {
      "subnet" = 100,
      "hosts"  = local.aws-us-east-1-hosts
    },
  }
  iam_instance_profile_name = var.iam_instance_profile_name
  all_endpoints = local.all_endpoints
  vpc_id        = local.aws-us-east-1-flattened[count.index].vpc_id
  vpc_nlb_subnet_id = local.aws-us-east-1-flattened[count.index].vpc_nlb_subnet_id
  vpc_controller_subnet_id = local.aws-us-east-1-flattened[count.index].vpc_controller_subnet_id
  use_nlb_and_asg       = var.use_nlb_and_asg
  instance_type = var.instance_type
  name          = var.name
  psk           = random_uuid.bowtie_psk
  key_name    = var.key_name
  subnets = null
}

module "site-aws-us-east-2" {
  count = length(local.aws-us-east-2-flattened)
  source                 = "./modules/site"
  dns_zone               = data.aws_route53_zone.org
  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_password))
  bowtie_sso_config_path = var.bowtie_sso_config_path
  providers              = { aws = aws.us-east-2 }
  instances = {
    "public" = {
      "subnet" = 100,
      "hosts"  = local.aws-us-east-2-hosts
    },
  }
  iam_instance_profile_name = var.iam_instance_profile_name
  all_endpoints = local.all_endpoints
  vpc_id        = local.aws-us-east-2-flattened[count.index].vpc_id
  vpc_nlb_subnet_id = local.aws-us-east-2-flattened[count.index].vpc_nlb_subnet_id
  vpc_controller_subnet_id = local.aws-us-east-2-flattened[count.index].vpc_controller_subnet_id
  use_nlb_and_asg       = var.use_nlb_and_asg
  instance_type = var.instance_type
  name          = var.name
  psk           = random_uuid.bowtie_psk
  key_name    = var.key_name
  subnets = null
}

module "site-aws-us-west-1" {
  count = length(local.aws-us-west-1-flattened)
  source                 = "./modules/site"
  dns_zone               = data.aws_route53_zone.org
  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_password))
  bowtie_sso_config_path = var.bowtie_sso_config_path
  providers              = { aws = aws.us-west-1 }
  instances = {
    "public" = {
      "subnet" = 100,
      "hosts"  = local.aws-us-west-1-hosts
    },
  }
  iam_instance_profile_name = var.iam_instance_profile_name
  all_endpoints = local.all_endpoints
  vpc_id        = local.aws-us-west-1-flattened[count.index].vpc_id
  vpc_nlb_subnet_id = local.aws-us-west-1-flattened[count.index].vpc_nlb_subnet_id
  vpc_controller_subnet_id = local.aws-us-west-1-flattened[count.index].vpc_controller_subnet_id
  use_nlb_and_asg       = var.use_nlb_and_asg
  instance_type = var.instance_type
  name          = var.name
  psk           = random_uuid.bowtie_psk
  key_name    = var.key_name
  subnets = null
}

module "site-aws-us-west-2" {
  count = length(local.aws-us-west-2-flattened)
  source                 = "./modules/site"
  dns_zone               = data.aws_route53_zone.org
  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_password))
  bowtie_sso_config_path = var.bowtie_sso_config_path
  providers              = { aws = aws.us-west-2 }
  instances = {
    "public" = {
      "subnet" = 100,
      "hosts"  = local.aws-us-west-2-hosts
    },
  }
  iam_instance_profile_name = var.iam_instance_profile_name
  all_endpoints = local.all_endpoints
  vpc_id        = local.aws-us-west-2-flattened[count.index].vpc_id
  vpc_nlb_subnet_id = local.aws-us-west-2-flattened[count.index].vpc_nlb_subnet_id
  vpc_controller_subnet_id = local.aws-us-west-2-flattened[count.index].vpc_controller_subnet_id
  use_nlb_and_asg       = var.use_nlb_and_asg
  instance_type = var.instance_type
  name          = var.name
  psk           = random_uuid.bowtie_psk
  key_name    = var.key_name
  subnets = null
}



provider "bowtie" {
  host     = local.bowtie_endpoint
  username = var.bowtie_admin_email
  password = var.bowtie_password
}


module "bowtie-org" {
  #depends_on = [checkmate_http_health.baseline_up]
  source    = "./modules/bowtie"
  providers = { bowtie = bowtie }
  dns_zone  = data.aws_route53_zone.org
  endpoint  = local.bowtie_endpoint
  username  = var.bowtie_admin_email
  password  = var.bowtie_password
  name      = var.bowtie_name
  org_name = var.org_name

  // TODO Come back to this to name sites
  // - Get CIDRs from VPC
  sites = {}
}

resource "random_password" "GENERATED_PASSWORD" {
  length           = 16
  special          = false
}


output "bowtie_endpoints" {
  value = local.all_endpoints
}
