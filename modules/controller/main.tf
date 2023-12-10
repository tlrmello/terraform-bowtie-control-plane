locals {
  dns_records = [for v in var.instances : "${v}.${var.name}.${var.dns_zone.name}"]
  entrypoint_string = format("\"%s\"", join("\",\"", var.all_endpoints))
}

resource "aws_route53_record" "endpoint" {
  count = length(var.instances)
  zone_id = var.dns_zone.zone_id
  name    = local.dns_records[count.index]
  type    = var.use_nlb_and_asg ? "CNAME" : "A"
  ttl     = "60"
  records = [var.use_nlb_and_asg ? aws_lb.controller[count.index].dns_name : aws_instance.controller[count.index].public_ip]
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false
  count         = length(var.instances)

  part {
    filename     = "cloud-init.yml"
    content_type = "text/cloud-config"

    content = yamlencode({
      fqdn                      = local.dns_records[count.index]
      hostname                  = local.dns_records[count.index]
      preserve_hostname         = false
      prefer_fqdn_over_hostname = true

      write_files = concat([
        {
          path = "/var/lib/bowtie/skip-gui-init"
        },
        {
          path    = "/etc/bowtie-server.d/site.conf"
          content = <<-EOS
            SITE_ID=${var.site_id.result}
            BOWTIE_SYNC_PSK=${var.psk.result}
            BOWTIE_JOIN_STRATEGY=bootstrap-at-failure
          EOS
        }
        # "Am I the leader?"
        ], count.index == 0 ? [
        {
          path    = "/var/lib/bowtie/init-users"
          content = <<-EOS
            ${var.bowtie_admin_email}:${var.bowtie_hashed_password}
          EOS
        }
        # This instance is _not_ the leader
        ] : [],
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
  count = var.use_nlb_and_asg ? 0 : length(var.instances)
  ami                    = data.aws_ami.controller.id
  iam_instance_profile = var.iam_instance_profile_name
  subnet_id              = var.controller_subnet_id
  vpc_security_group_ids = var.security_groups
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
    Name = "${var.instances[count.index]}.${var.name}.${var.dns_zone.name}"
  }
}


/* Alternate strategy is to use an NLB and ASG of length 1 */
resource "aws_placement_group" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  name     = "${var.instances[count.index]}.${var.name}"
  strategy = "cluster"
}

resource "aws_launch_template" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  name   = "${var.instances[count.index]}.${var.name}"
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
    security_groups = var.security_groups
  }

  
}

resource "aws_autoscaling_group" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  name                      = "${var.instances[count.index]}.${var.name}"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.controller[count.index].id
  vpc_zone_identifier       = [var.controller_subnet_id]

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
    value               = "${var.instances[count.index]}.${var.name}.${var.dns_zone.name}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_lb" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  name                      = "${var.instances[count.index]}-${var.name}"
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.nlb_subnet_id]
  security_groups = var.security_groups

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  target_type = "instance"
  name = "${var.instances[count.index]}-${var.name}"
  port = 443
  protocol = "TCP_UDP"
  vpc_id = var.vpc_id
}

resource "aws_lb_listener" "controller" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
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
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  target_type = "instance"
  name = "${var.instances[count.index]}-${var.name}"
  port = 80
  protocol = "TCP"
  vpc_id = var.vpc_id
}

resource "aws_lb_listener" "controller-plain" {
  count = var.use_nlb_and_asg ? length(var.instances) : 0
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
  count = var.use_nlb_and_asg ? length(var.instances) : 0
  autoscaling_group_name = aws_autoscaling_group.controller[count.index].id
  lb_target_group_arn = aws_lb_target_group.controller[count.index].arn
}

/* -- outputs need thought after the changes --
output "public_ip" {
  value = { for i, v in aws_instance.controller : var.instances[i] => v.public_ip }
}

output "public_dns" {
  value = { for i, v in aws_route53_record.endpoint : var.instances[i] => v.name }
}
*/
