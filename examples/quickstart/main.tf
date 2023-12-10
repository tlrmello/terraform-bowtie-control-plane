
module "bowtie-with-aws" {
    source = "terraform-bowtie-control-plane"
    # version = "0.1.0"

    # key name is possible to use, if your key name is consistent across regions
    # key_name = "issac@angmar"

    # The name of the DNS zone within the AWS account. Public DNS names will
    # appear underneath this domain.
    dns_zone_name = "rock.associates"

    # Bowtie initial user settings that will pre-seed the Controller.
    bowtie_admin_email = "issac@bowtie.works"
    bowtie_password = "Ad9067322-9f34-45c3-bb30-55ea4c0143f3NicelyRandomized St23ing"

    // This shows up in user-facing menus and
    // the network interface name is derived from this on endpoints
    org_name = "Rock Associates"

    # These fields are optional
    # instance_type = "m5.large"
    # iam_instance_profile_name = "bowtie-ssm-test"

    // Associate each controller with an ASG of unit 1, and a one-unit NLB to protect
    // against instance failures
    use_nlb_and_asg = true

    aws-us-east-2 = [
        {
            vpc_id = "vpc-03f5ade378a335f98",
            subnets = [
                {
                    number_of_controllers = 2,
                    host_prefix = "ohio-b-"
                    vpc_controller_subnet_id = data.aws_subnet.private-east-2b.id,
                    vpc_nlb_subnet_id = data.aws_subnet.public-east-2b.id,
                }
            ]
        }
    ]

    aws-us-west-2 = [
        {
            vpc_id = "vpc-083d61b2bde725277",
            subnets = [
                {
                    number_of_controllers = 2,
                    host_prefix = "ohio-b-"
                    vpc_controller_subnet_id = "subnet-01bfc36b04578e926",
                    vpc_nlb_subnet_id = "subnet-0860f6f38faa94025",
                }
            ]
        }
    ]   

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