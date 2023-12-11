## Bowtie Controller Appliances & Configuration Terraform

A quickstart-type module for deploying a highly available bowtie control plane.

This currently supports AWS to have one-step control plane installation and configuration. This is a "batteries-included" type installation. You are of course able to build your own modules on top of `terraform-provider-bowtie`, optionally chosing any other providers you need. 

Copyright &copy; 2023 Bowtie Works, Inc. Licensed under Apache License 2.0

### Terraform

To succeed, you’ll need:

- Access to an AWS account -- my quick litmus test is `aws s3 ls` to confirm I’m in the right place and authenticated.
- A pre-existing Route53 zone to tinker inside of. We call our test organization, `rock.associates` in any examples you may see. That should stand in for your organization and DNS Zone.

#### Example Use

Check `examples` folder for a complete quickstart