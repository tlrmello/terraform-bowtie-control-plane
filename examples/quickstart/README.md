# Terraform Bowtie Control Plane Quickstart Example

This Bowtie module will deploy a set of controllers in a given VPC, or if no VPC is given, will create the basic AWS infrastructure necessary for a minimal deployment. If desired, the module will deploy the controllers behind network load balancers and in auto scaling groups.

To deploy into more than one VPC, the module may be used more than once in a single terraform configuration. 

For a given VPC, more than one subnet may be given to deploy into alternating availability zones by specifying multiple subnet entries for the VPC.

Both the initial administrative user's password and the bowtie_sync_psk are sensitive values that should be guarded as secret and stored securely, such as in AWS Secrets Manager or AWS SSM Parameter Store.
