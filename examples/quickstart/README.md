# Terraform Bowtie Control Plane Quickstart Example

This Bowtie module will deploy a set of controllers in a given VPC. If desired, the module will deploy the controllers behind network load balancers and in auto scaling groups.

To deploy into more than one VPC, the module may be used more than once in a single terraform configuration. The resulting hostnames must be declared as a variable list so that the controllers can discover one another and cluster together.

For a given VPC, more than one subnet may be given to deploy into alternating availability zones by specifying multiple subnet entries for the VPC.

Both the initial administrative user's password and the bowtie_sync_psk are sensitive values that should be guarded as secret and stored securely, such as in AWS Secrets Manager or AWS SSM Parameter Store.