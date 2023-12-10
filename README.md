## Bowtie Controller Appliances & Configuration Terraform

A quickstart-type module for deploying a highly available bowtie control plane.

This currently supports AWS to have one-step control plane installation and configuration. This is a "batteries-included" type installation. You are of course able to build your own modules on top of `terraform-provider-bowtie`, optionally chosing any other providers you need. 

Copyright &copy; 2023 Bowtie Works, Inc. Licensed under Apache License 2.0

### Terraform

To succeed, you’ll need:

- Access to an AWS account -- my quick litmus test is `aws s3 ls` to confirm I’m in the right place and authenticated.
- A pre-existing Route53 zone to tinker inside of. We call our test organization, `rock.associates` in any examples you may see. That should stand in for your organization and DNS Zone.

#### Example Use

```
module "bowtie-control-plane" {
    source = "../terraform-bowtie-with-aws"
    version = "0.1.0"

    # Optional and must be the same name in all sites
    key_name = "Teddy Rosevelt @ Laptop"

    # The name of the DNS zone within the AWS account. Public DNS names will
    # appear underneath this domain.
    dns_zone_name = "rock.associates"

    # A unique string that your deployment will live under.
    # Final hostnames will look like: alpha.${name}.${dns_zone_name}
    name = "sparky-torvalds"

    # Bowtie initial user settings that will pre-seed the Controller.
    bowtie_admin_email = "your-sso-email@example.com"
    bowtie_name     = "Firstname Lastname"

    # You should almost certainly use a secret manager or a well-protected environment variable for this. 
    bowtie_password        = "6abfdd6488c6ad4b46ced3202c285b67"

    # Optional if you want to configure SSO. Requires that you have the new
    # domains as a trusted callback in your configured SSO provider. We have an
    # example one with org details in controller/dex-gitlab.yaml
    # bowtie_sso_config_path = "/home/teddyroosevelt/src/bowtie/controller/dex-gitlab.yaml"
}
```
