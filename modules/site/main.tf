terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}


resource "aws_security_group" "public" {
  name        = "${var.name} public security group"
  description = "${var.name} Bowtie Controllers"
  vpc_id      = var.vpc_id

  /* TODO Conditional? 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  */
  
  /* If we need to enable the zerossl fallback, that's here
  // For ZeroSSL Fallback
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  */
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # The "permit all outbound traffic" rule:
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "random_uuid" "site_id" {}

# This is where actual instances are built; abstracted into a module
# to more easily instantiate >1 at a time.
module "controller" {
  source = "../controller"

  bowtie_admin_email        = var.bowtie_admin_email
  bowtie_hashed_password = var.bowtie_hashed_password
  bowtie_sso_config_path = var.bowtie_sso_config_path
  dns_zone               = var.dns_zone
  instances              = var.instances["public"]["hosts"]
  iam_instance_profile_name = var.iam_instance_profile_name
  instance_type          = var.instance_type
  key_name               = var.key_name
  all_endpoints          = var.all_endpoints
  name                   = var.name
  psk                    = var.psk
  use_nlb_and_asg        = var.use_nlb_and_asg
  site_id                = random_uuid.site_id
  controller_subnet_id   = var.vpc_controller_subnet_id
  nlb_subnet_id          = var.vpc_nlb_subnet_id
  vpc_id                 = var.vpc_id
  security_groups = [
    aws_security_group.public.id,
  ]
}

/* -- outputs need thought after the changes --
output "public_ip" {
  value = module.controller.public_ip
}

output "public_dns" {
  value = module.controller.public_dns
}

output "site_id" {
  value = random_uuid.site_id.result
}
*/