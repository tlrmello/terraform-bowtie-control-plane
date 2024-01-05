terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

locals {
  flattened-instances = flatten([
    for i in range(0, length(var.subnets)): [
      for j in range(0, var.subnets[i].number_of_controllers): {
          name = format("%s%02d", var.subnets[i].host_prefix, j),
          dns_name = "${format("%s%02d", var.subnets[i].host_prefix, j)}.${var.name}.${var.dns_zone_name}",
          vpc_id = var.vpc_id,
          vpc_controller_subnet_id = var.subnets[i].vpc_controller_subnet_id,
          site_id = var.subnets[i].site_id,
          vpc_nlb_subnet_id = var.subnets[i].vpc_nlb_subnet_id,
        }
    ]
  ])
  hosts_short = [for i in range(0, length(local.flattened-instances)) : local.flattened-instances[i].name]
  dns_hosts_short = [for i in range(0, length(local.flattened-instances)) : local.flattened-instances[i].dns_name]

  bootstrap_from = coalesce(var.bootstrap_hosts, dns_hosts_short)

  bootstrap_hosts_urls = [
    for i in range(0, length(bootstrap_from)):
      format("https://%s", bootstrap_from[i])
  ]

  entrypoint_string = format("\"%s\"", join("\",\"", local.bootstrap_hosts_urls))

  init-users-text = join("\n", [
    for i in range(0, length(var.init-users)):
      "${var.init-users[i].email}:${var.init-users[i].hashed_password}"
  ])
}

data "aws_route53_zone" "org" {
  name         = var.dns_zone_name
  private_zone = false
}

module "synthesized_vpc" {
  source = "../aws_vpc_synthesis"
  vpc_id = var.vpc_id
  vpc = var.vpc
}

resource "aws_security_group" "public" {
  name        = "${var.name} public security group"
  description = "${var.name} Bowtie Controllers"
  vpc_id      = module.synthesized_vpc.vpc_id


  /* TODO Paramaterize.
  Potentially paramaterizing this means allowing one SG per Subnet
  So maybe we should do that now, if the resource will be dynamic in the future
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }*/
  
  /* If we need to enable the zerossl fallback, that's here
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

resource "aws_route53_record" "endpoint" {
  count = var.operate_route53 ? length(local.flattened-instances) : 0
  zone_id = data.aws_route53_zone.org.zone_id
  name    = local.flattened-instances[count.index].dns_name
  type    = var.use_nlb_and_asg ? "CNAME" : "A"
  ttl     = "60"
  records = [var.use_nlb_and_asg ? aws_lb.controller[count.index].dns_name : aws_instance.controller[count.index].public_ip]
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false
  count         = length(local.flattened-instances)

  part {
    filename     = "cloud-init.yml"
    content_type = "text/cloud-config"

    content = yamlencode({
      fqdn                      = local.flattened-instances[count.index].dns_name
      hostname                  = local.flattened-instances[count.index].dns_name
      preserve_hostname         = false
      prefer_fqdn_over_hostname = true

      write_files = concat([
        {
          path = "/var/lib/bowtie/skip-gui-init"
        },
        {
          path    = "/etc/bowtie-server.d/site.conf"
          content = <<-EOS
            SITE_ID=${local.flattened-instances[count.index].site_id}
            BOWTIE_SYNC_PSK=${var.sync_psk}
            BOWTIE_JOIN_STRATEGY=bootstrap-at-failure
          EOS
        }
        ],
        [
        {
          path    = "/var/lib/bowtie/init-users"
          content = local.init-users-text
        }
        ],
        [
        {
          path    = "/var/lib/bowtie/should-join.conf"
          content = <<-EOS
            entrypoints = [ ${local.entrypoint_string} ]
          EOS
        }
        # "Did I get an SSO file?"
        ], var.bowtie_sso_config_path != null ? [
        {
          path    = "/etc/dex/${basename(var.bowtie_sso_config_path)}"
          content = <<-EOS
            ${indent(4, file(var.bowtie_sso_config_path))}
          EOS
        }
      ] : [])
    })
  }
}

# Because our root Bowtie account only publishes Controller AMIs, this
# is sufficient for now.
#
# TODO: Add tags to our controllers because we definitely need a way
# to target AMIs more specifically rather than just "latest AMI from
# Bowtie"
data "aws_ami" "controller" {
  most_recent = true
  owners      = ["055761336000"] # Bowtie
}

# Actual EC2 instance
resource "aws_instance" "controller" {
  count = var.use_nlb_and_asg ? 0 : length(local.flattened-instances)
  ami                    = data.aws_ami.controller.id
  iam_instance_profile = var.iam_instance_profile_name
  subnet_id              = coalesce(local.flattened-instances[count.index].vpc_controller_subnet_id, module.synthesized_vpc.vpc_id)
  vpc_security_group_ids = [aws_security_group.public.id]
  instance_type          = var.instance_type
  key_name               = var.key_name

  root_block_device {
    # Not needed for root
    # device_name = "/dev/xvda"
    volume_size = 64
    volume_type = "gp2"
    delete_on_termination = "true"
  }

  user_data                   = data.cloudinit_config.user_data[count.index].rendered
  user_data_replace_on_change = true

  tags = {
    Name = "${local.flattened-instances[count.index].dns_name}"
  }
}


/* Alternate strategy is to use an NLB and ASG of length 1 */
resource "aws_placement_group" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  name     = "${local.flattened-instances[count.index].name}"
  strategy = "cluster"
}

resource "aws_launch_template" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  name   = "${local.flattened-instances[count.index].name}"
  key_name               = var.key_name
  image_id                    = data.aws_ami.controller.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  user_data = base64encode(data.cloudinit_config.user_data[count.index].rendered)
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 64
      volume_type = "gp2"
      delete_on_termination = "true"
    }
  }
  network_interfaces {
    security_groups = [aws_security_group.public.id]
  }  
}

resource "aws_autoscaling_group" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  name                      = "${local.flattened-instances[count.index].name}"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.controller[count.index].id
  vpc_zone_identifier       = [coalesce(local.flattened-instances[count.index].vpc_controller_subnet_id, module.synthesized_vpc.vpc_private_subnet_id)]

  launch_template {
    id =  aws_launch_template.controller[count.index].id
    version = "$Latest"
  }

  instance_maintenance_policy {
    min_healthy_percentage = 90
    max_healthy_percentage = 120
  }

  tag {
    key                 = "Name"
    value               = "${local.flattened-instances[count.index].dns_name}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_lb" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  name                      = "${local.flattened-instances[count.index].name}"
  internal           = false
  load_balancer_type = "network"
  subnets            = [coalesce(local.flattened-instances[count.index].vpc_nlb_subnet_id, module.synthesized_vpc.vpc_public_subnet_id)]
  security_groups = [aws_security_group.public.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  target_type = "instance"
  name = "${local.flattened-instances[count.index].name}"
  port = 443
  protocol = "TCP_UDP"
  vpc_id = module.synthesized_vpc.vpc_id
}

resource "aws_lb_listener" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  load_balancer_arn = aws_lb.controller[count.index].arn
  port              = "443"
  protocol          = "TCP_UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controller[count.index].arn
  }
}

/* If we need to enable the zerossl fallback, that's here
resource "aws_lb_target_group" "controller-plain" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  target_type = "instance"
  name = "${local.flattened-instances[count.index]}-${var.name}"
  port = 80
  protocol = "TCP"
  vpc_id = var.vpc_id
}

resource "aws_lb_listener" "controller-plain" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  load_balancer_arn = aws_lb.controller[count.index].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controller[count.index].arn
  }
}
*/

resource "aws_autoscaling_attachment" "controller" {
  count = var.use_nlb_and_asg ? length(local.flattened-instances) : 0
  autoscaling_group_name = aws_autoscaling_group.controller[count.index].id
  lb_target_group_arn = aws_lb_target_group.controller[count.index].arn
}

// -- outputs need thought after the changes --
// output "public_ip" {
//  value = { for i, v in aws_instance.controller : local.flattened-instances[i] => v.public_ip }
// }

output "route_53_dns" {
  value = var.operate_route53 ? { for i, v in aws_route53_record.endpoint : local.flattened-instances[i].name => v.name } : {}
}

output "public_dns" {
  value = var.use_nlb_and_asg ? { for i, v in aws_lb.controller : local.flattened-instances[i].name => v.dns_name } : { for i, v in aws_instance.controller : local.flattened-instances[i] => v.public_dns }
}


