terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

// This will genrate a random site_id for every site. If you pass one in, that will be used instead.
resource "random_uuid" "generated_site_id" {
  count = length(var.subnets)
}

locals {
  flattened-instances = flatten([
    for i in range(0, length(var.subnets)): 
      try(length(var.subnets[i].names), 0) > 0 ? # if names exist, use those
      [
        for j in range(0, length(var.subnets[i].names)): {
            name = var.subnets[i].names[j]
            dns_name = "${var.subnets[i].names[j]}.${var.dns_zone_name}",
            vpc_id = var.vpc_id,
            vpc_controller_subnet_id = var.subnets[i].vpc_controller_subnet_id,
            site_id = var.subnets[i].site_id,
            site_index = i,
            vpc_nlb_subnet_id = var.subnets[i].vpc_nlb_subnet_id,
          }
      ]
      : # otherwise, use generated ones
      [
        for j in range(0, var.subnets[i].number_of_controllers): {
            name = format("%s%02d", var.subnets[i].host_prefix, j),
            dns_name = "${format("%s%02d", var.subnets[i].host_prefix, j)}.${var.name}.${var.dns_zone_name}",
            vpc_id = var.vpc_id,
            vpc_controller_subnet_id = var.subnets[i].vpc_controller_subnet_id,
            site_id = var.subnets[i].site_id,
            site_index = i,
            vpc_nlb_subnet_id = var.subnets[i].vpc_nlb_subnet_id,
          }
      ]
  ])

  user_datas = {
    for i in range(0, length(local.flattened-instances)):
      local.flattened-instances[i].name => local.flattened-instances[i]
  }

  hosts_short = [for i in range(0, length(local.flattened-instances)) : local.flattened-instances[i].name]
  dns_hosts_short = [for i in range(0, length(local.flattened-instances)) : local.flattened-instances[i].dns_name]

  bootstrap_from = coalesce(var.bootstrap_hosts, local.dns_hosts_short)

  bootstrap_hosts_urls = [
    for i in range(0, length(local.bootstrap_from)):
      format("https://%s", local.bootstrap_from[i])
  ]

  entrypoint_string = format("\"%s\"", join("\",\"", local.bootstrap_hosts_urls))

  init-users-text = join("\n", [
    for i in range(0, length(var.init-users)):
      "${var.init-users[i].email}:${var.init-users[i].hashed_password}"
  ])

  // Make an empty map for iam_instance_profile in the launch template if you aren't going to use it.
  // this feeds into a dynamic block below
  // TODO this should be a dictionary
  use_iam_instance_profile =  try(length(var.iam_instance_profile_name), 0) > 0 ? {
    iam_instance_profile = var.iam_instance_profile_name
  } : {}
}

data "aws_route53_zone" "org" {
  count = var.operate_route53 ? 1 : 0
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
  zone_id = data.aws_route53_zone.org.0.zone_id
  name    = local.flattened-instances[count.index].dns_name
  type    = var.use_nlb_and_asg ? "CNAME" : "A"
  ttl     = "60"
  records = [var.use_nlb_and_asg ? aws_lb.controller[count.index].dns_name : aws_instance.controller[count.index].public_ip]
}

data "cloudinit_config" "user_data" {
  // gzip is suggested to solve the user_data idempotency issue but does not.
  gzip          = true
  base64_encode = true
  
  // Attempting a for_each instead of a count here because it might
  // not register changes if the underlying data changes. 
  // This turned out to be false but I do think it's a little bit nicer code.
  for_each = local.user_datas

  part {
    filename     = "cloud-init.yml"
    content_type = "text/cloud-config"

    content = yamlencode({
      fqdn                      = each.value.dns_name
      hostname                  = each.value.dns_name
      preserve_hostname         = false
      prefer_fqdn_over_hostname = true

      write_files = concat([
        {
          path = "/var/lib/bowtie/skip-gui-init"
        },
        {
          path    = "/etc/bowtie-server.d/site.conf"
          content = <<-EOS
            SITE_ID=${coalesce(each.value.site_id, random_uuid.generated_site_id[each.value.site_index].result)}
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

  // put-only user_data is not ideal, but it's better than reaping the resource
  lifecycle {
    ignore_changes = [user_data]
  }
  user_data                   = data.cloudinit_config.user_data[local.flattened-instances[count.index].name].rendered
  user_data_replace_on_change = false

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
  key_name               = var.key_name
  image_id                    = data.aws_ami.controller.id
  instance_type = var.instance_type

  // If iam_instance_profile is null, we need to set the variable to null not an empty object
  dynamic iam_instance_profile {
    for_each = local.use_iam_instance_profile
    content {
      name = var.iam_instance_profile_name
    }
  }

  lifecycle {
    ignore_changes = [user_data]
  }
  user_data = data.cloudinit_config.user_data[local.flattened-instances[count.index].name].rendered
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

output "route_53_dns" {
  value = var.operate_route53 ? { for i, v in aws_route53_record.endpoint : local.flattened-instances[i].name => v.name } : {}
}

output "public_dns" {
  description = "key is the controller's short name, value is the associated dns name or NLB's dns name"
  value = var.use_nlb_and_asg ? { for i, v in aws_lb.controller : local.flattened-instances[i].name => v.dns_name } : { for i, v in aws_instance.controller : local.flattened-instances[i] => v.public_dns }
}

output "nlb_to_instance_name" {
  description = "key is the controller's reachable name, value is the associated NLB's dns name"
  value = var.use_nlb_and_asg ? { for i, v in aws_lb.controller : local.flattened-instances[i].dns_name => v.dns_name } : {}
}

output "nlb_zone_id_to_instance_name" {
  description = "key is the controller's reachable name, value is the associated NLB's zone_id"
  value = var.use_nlb_and_asg ? { for i, v in aws_lb.controller : local.flattened-instances[i].dns_name => v.zone_id } : {}
}
