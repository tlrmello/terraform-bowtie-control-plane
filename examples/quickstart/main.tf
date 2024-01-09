terraform {
  required_providers {
    bowtie = {
      source = "bowtieworks/bowtie"
      version = "0.5.1"
    }
  }
}

locals {
  // You may substitute these local values as variables if desired.
  west_name = "west-"
  east_name = "east-"

  // One initial bootstrap host per region should be defined.
  // The first host in a region, denoted with "00", is utilized for bootstrap.
  bootstrap_hosts = [
    "${local.west_name}00.${var.control_plane_name}.${var.dns_zone_name}",
    "${local.east_name}00.${var.control_plane_name}.${var.dns_zone_name}",
  ]

}


// This example demonstrates retrieving sensitive values from Amazon SSM.
// You may instead use secret environment variables, Hashicorp Vault, or 
// an equivalent secrets management strategy.

// The initial administrative user password is sensitive and should be handled
// with care.
data "aws_ssm_parameter" "password" {
  name = "/bowtie/admin/password"
  provider = aws.us-east-2
}

// The cluster synchronization pass key is sensitive and should be handled with
// care.
data "aws_ssm_parameter" "sync-psk" {
  name = "/bowtie/admin/sync-psk"
  provider = aws.us-east-2
}

resource "random_uuid" "us-west-2-site-id" {}
resource "random_uuid" "us-east-2-site-id" {}

// Define one module per VPC. Two are declared here to demonstrate a cross-
// regional deployment.
module "bowtie_us_west_2" {
    source = "bowtieworks/control-plane/bowtie//modules/aws_vpc"

    // You may provide an instance profile to associate with controller
    // instances.
    //iam_instance_profile_name = "Something with SSM"

    // You may optionally define the name of an existing SSH key to seed
    // instances with.
    //key_name = "Existing Key Name"

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
    bootstrap_hosts = local.bootstrap_hosts

    dns_zone_name = var.dns_zone_name
    sync_psk = data.aws_ssm_parameter.sync-psk.value

    // You may utilize a data source to identify subnets or specify the target
    // IDs statically. You may also have VPCs created for you, as shown in the
    // next module example below.
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

    // You may provide an instance profile to associate with controller
    // instances.
    //iam_instance_profile_name = "Something with SSM"
    
    // You may optionally define the name of an existing SSH key to seed
    // instances with.
    //key_name = "Existing Key Name"

    // True: Associate each controller with an ASG of unit 1, and a one-unit NLB to protect
    // against instance failures
    // False (default): will launch a normal instance, and you should use a public
    // security group for the controller
    use_nlb_and_asg = true

    init-users = [{
      email = var.bowtie_admin_email
      hashed_password = format("$bcrypt%s", bcrypt(data.aws_ssm_parameter.password.value))
    }]
    
    providers = { aws = aws.us-east-2 }
    name = var.control_plane_name
    bootstrap_hosts = local.bootstrap_hosts

    dns_zone_name = "rock.associates"
    sync_psk = data.aws_ssm_parameter.sync-psk.value

    // In this example, when a VPC ID is not provided via a data source or
    // statically defined, you may instead specify network CIDRs with which to
    // create a new VPC in this region.
    vpc = {
      vpc_cidr = "10.98.0.0/16"
      private_cidr = "10.98.1.0/24"
      public_cidr = "10.98.244.0/24"
    }
    subnets = [
        {
            number_of_controllers = 2,
            host_prefix = local.east_name,
            site_id = random_uuid.us-east-2-site-id.result,
        }
    ]
}

module "bowtie-control-plane" {
    source  = "bowtieworks/control-plane/bowtie"
    version = ">= 0.2.5, < 0.3.0"
    depends_on = [
      module.bowtie_us_east_2,
      module.bowtie_us_west_2
    ]

    api_hostname     = "https://${local.bootstrap_hosts[0]}"
}

// The following examples demonstrate obtaining subnet IDs.
//data "aws_subnet" "private-east-2b" {
//    availability_zone = "us-east-2b"
//    filter {
//        name   = "map-public-ip-on-launch"
//        values = ["No", false]
//    }
//}
//data "aws_subnet" "public-east-2b" {
//    availability_zone = "us-east-2b"
//    filter {
//        name   = "map-public-ip-on-launch"
//        values = ["Yes", true]
//    }
//    filter {
//        name   = "cidr-block"
//        values = ["172.16.80.0/24"]
//    }
//}

provider "bowtie" {
  host     = "https://${local.bootstrap_hosts[0]}"
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
