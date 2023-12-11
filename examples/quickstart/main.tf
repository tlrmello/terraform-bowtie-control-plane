terraform {
  required_providers {
    bowtie = {
      source = "bowtieworks/bowtie"
      version = "0.4"
    }
  }
}

resource "random_uuid" "bowtie_psk" {}

locals {
  sync_psk = coalesce(var.bowtie_sync_psk, random_uuid.bowtie_psk)
}

resource "random_uuid" "us-west-2-site-id" {}
resource "random_uuid" "us-east-2-site-id" {}

// One module per VPC, we'll sort out the rest.
module "bowtie_us_west_2" {
    source = "bowtie/control-plane/modules/aws_vpc"

    key_name = "issac@angmar"

    // True: Associate each controller with an ASG of unit 1, and a one-unit NLB to protect
    // against instance failures
    // False (default): will launch a normal instance, and you should use a public
    // security group for the controller
    use_nlb_and_asg = true

    init-users = [{
      email = var.bowtie_admin_email
      hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_admin_password))
    }]

    providers = { aws = aws.us-west-2 }
    name = var.control_plane_name
    bootstrap_hosts = var.bootstrap_hosts

    dns_zone_name = "rock.associates"
    sync_psk = local.sync_psk

    vpc_id = "vpc-083d61b2bde725277"
    subnets = [
        {
            number_of_controllers = 2,
            host_prefix = "oregon-a-",
            site_id = random_uuid.us-west-2-site-id.result,
            vpc_controller_subnet_id = "subnet-01bfc36b04578e926",
            vpc_nlb_subnet_id = "subnet-0860f6f38faa94025",
        }
    ]
}

module "bowtie_us_east_2" {
    source = "bowtie/control-plane/modules/aws_vpc"
    
    key_name = "Issac Laptop (Angmar)"

    init-users = [{
      email = var.bowtie_admin_email
      hashed_password = format("$bcrypt%s", bcrypt(var.bowtie_admin_password))
    }]
    
    use_nlb_and_asg = true

    providers = { aws = aws.us-east-2 }
    name = var.control_plane_name

    dns_zone_name = "rock.associates"
    sync_psk = local.sync_psk

    bootstrap_hosts = var.bootstrap_hosts

    // Optional
    // iam_instance_profile_name = "Something with SSM"

    vpc_id = "vpc-03f5ade378a335f98"
    subnets = [
        {
            number_of_controllers = 2,
            host_prefix = "ohio-b-",
            site_id = random_uuid.us-east-2-site-id.result,
            vpc_controller_subnet_id = data.aws_subnet.private-east-2b.id,
            vpc_nlb_subnet_id = data.aws_subnet.public-east-2b.id,
        }
    ]
}

module "bowtie-control-plane" {
    depends_on = [
      module.bowtie_us_east_2,
      module.bowtie_us_west_2
    ]

    api_hostname     = "https://${var.bootstrap_hosts[0]}"
    source = "bowtie/control-plane"

    # The name of the DNS zone within the AWS account. Public DNS names will
    # appear underneath this domain.

    // This shows up in user-facing menus and
    // the network interface name is derived from this on endpoints
    org_name = "Rock Associates"
}

data "aws_subnet" "private-east-2b" {
    availability_zone = "us-east-2b"
    filter {
        name   = "map-public-ip-on-launch"
        values = ["No", false]
    }
}
data "aws_subnet" "public-east-2b" {
    availability_zone = "us-east-2b"
    filter {
        name   = "map-public-ip-on-launch"
        values = ["Yes", true]
    }
    filter {
        name   = "cidr-block"
        values = ["172.16.80.0/24"]
    }
}

provider "bowtie" {
  host     = "https://${var.bootstrap_hosts[0]}"
  username = var.bowtie_admin_email
  password =  var.bowtie_admin_password
}

provider "aws" {
  region = "us-east-2"
  alias  = "us-east-2"

  default_tags {
    tags = {
      created-by = "terraform"
      managed-by = "terraform"
      Name       = "${var.control_plane_name} cluster"
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
      Name       = "${var.control_plane_name} cluster"
    }
  }
}