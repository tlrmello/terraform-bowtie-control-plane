terraform {
  required_providers {
    bowtie = {
      source = "bowtieworks/bowtie"
      version = "0.5.1"
    }
  }
}

// This example shows using amazon SSM for secrets
// You could of course use secret environment variables, Vault, or another secret manager
data "aws_ssm_parameter" "password" {
  name = "/bowtie/admin/password"
  provider = aws.us-east-2
}

data "aws_ssm_parameter" "sync-psk" {
  name = "/bowtie/admin/sync-psk"
  provider = aws.us-east-2
}

resource "random_uuid" "us-west-2-site-id" {}
resource "random_uuid" "us-east-2-site-id" {}

// One module per VPC, we'll sort out the rest.
module "bowtie_us_west_2" {
    source = "bowtieworks/control-plane/bowtie//modules/aws_vpc"

    // True: Associate each controller with an ASG of unit 1, and a one-unit NLB to protect
    // against instance failures
    // False (default): will launch a normal instance, and you should use a public
    // security group for the controller
    use_nlb_and_asg = true

    init-users = [{
      email = var.bowtie_admin_email
      hashed_password = format("$bcrypt%s", bcrypt(data.aws_ssm_parameter.password.value))
    }]

    providers = { aws = aws.us-west-2 }
    name = var.control_plane_name
    bootstrap_hosts = var.bootstrap_hosts

    dns_zone_name = var.dns_zone_name
    sync_psk = data.aws_ssm_parameter.sync-psk.value

    // You can import or give direct strings here.
    vpc_id = "vpc-00000011110000"
    subnets = [
        {
            number_of_controllers = 1,
            host_prefix = "west-a-",
            site_id = random_uuid.us-west-2-site-id.result,
            vpc_controller_subnet_id = "subnet-7770011110000",
            vpc_nlb_subnet_id = "subnet-88800011110000",
        },
        {
            number_of_controllers = 1,
            host_prefix = "west-b-",
            site_id = random_uuid.us-west-2-site-id.result,
            vpc_controller_subnet_id = "subnet-55500011110000",
            vpc_nlb_subnet_id = "subnet-9990011110000",
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
    sync_psk = data.aws_ssm_parameter.sync-psk.value

    bootstrap_hosts = var.bootstrap_hosts

    // Optional
    // iam_instance_profile_name = "Something with SSM"

    vpc_id = "vpc-03f5ade378a335f98"
    subnets = [
        {
            number_of_controllers = 2,
            host_prefix = "east-",
            vpc_controller_subnet_id = data.aws_subnet.private-east-2b.id,
            vpc_nlb_subnet_id = data.aws_subnet.public-east-2b.id,
        }
    ]
}

module "bowtie-control-plane" {
    source  = "bowtieworks/control-plane/bowtie"
    version = ">= 0.2.4, < 0.3.0"
    depends_on = [
      module.bowtie_us_east_2,
      module.bowtie_us_west_2
    ]

    api_hostname     = "https://${var.bootstrap_hosts[0]}"

    # The name of the DNS zone within the AWS account. Public DNS names will
    # appear underneath this domain.

    // This shows up in user-facing menus and
    // the network interface name is derived from this on endpoints
    org_name = "Example Environment"
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
  password =  data.aws_ssm_parameter.password.value
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