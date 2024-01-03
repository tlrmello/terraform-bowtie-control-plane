# This internal module exists so that the vpc_id can be given, or optionally generated, but still shows up as if it were generated.
# It does not have a README because it is intended for internal use.

variable vpc_id {
    description = "To use an existing VPC, insert it's ID here. For development, testing or other greenfield needs, a created vpc object may be more appropriate"
    type = string
    default = null
    nullable = true
}

variable vpc_public_subnet_id {
    description = "To use an existing VPC, insert the ID of the `public` subnet ID here."
    default = false
}

variable vpc_private_subnet_id {
    description = "To use an existing VPC, insert the ID of the `private` subnet ID here. In some installations this may be the same instance, but we recommend not giving public IPs to these by default."
    default = false
}

variable vpc {
    description = "To have this module own your VPC, place values here instead of using vpc_id"
    type = object({
        vpc_cidr = string
        private_cidr = string
        public_cidr = string
    })
    default = null
    nullable = true
}


# Managed VPC
resource "aws_vpc" "vpc" {
  # This is a complicated value to say "Make one if there is value in the object"
  # There is not an easy way to further validate the object as either existing or null, but if it is existing must follow some guidelines.

  count = can(var.vpc.vpc_cidr) ? 1 : 0
  cidr_block                       = var.vpc.vpc_cidr
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "Bowtie VPC"
  }
}

data "aws_region" "current" {}

# Public Subnet
resource "aws_subnet" "public" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  cidr_block = var.vpc.public_cidr
  vpc_id            = aws_vpc.vpc[0].id
  availability_zone = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${data.aws_region.current.name}a"
  }

  depends_on = [aws_vpc.vpc]
}

# Private Subnet
resource "aws_subnet" "private" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  cidr_block = var.vpc.private_cidr
  vpc_id            = aws_vpc.vpc[0].id
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "private-${data.aws_region.current.name}a"
  }

  depends_on = [aws_vpc.vpc]
}


# Internet Gateway
resource "aws_internet_gateway" "internetgateway" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id

  tags = {
    Name = "Bowtie-InternetGateway"
  }

  depends_on = [aws_vpc.vpc]
}

# Elastic IP
resource "aws_eip" "elasticIP" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.internetgateway]
}

# NAT Gateway
resource "aws_nat_gateway" "natgateway" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  allocation_id = aws_eip.elasticIP[0].id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.internetgateway]
}

# Route Table for Public Routes
resource "aws_route_table" "publicroutetable" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internetgateway[0].id
  }

  depends_on = [aws_internet_gateway.internetgateway]
}

# Route Table Association - Public Routes
resource "aws_route_table_association" "routeTableAssociationPublicRoute" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  route_table_id = aws_route_table.publicroutetable[0].id
  subnet_id      = aws_subnet.public[0].id

  depends_on = [aws_subnet.public,  aws_route_table.publicroutetable]
}

# Route Table for Private Routes
resource "aws_route_table" "privateroutetable" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway[0].id
  }

  depends_on = [aws_nat_gateway.natgateway]
}

# Route Table Association - Private Routes
resource "aws_route_table_association" "routeTableAssociationPrivateRoute" {
  count = can(var.vpc.vpc_cidr) ? 1 : 0
  route_table_id = aws_route_table.privateroutetable[0].id
  subnet_id      = aws_subnet.private[0].id

  depends_on = [aws_subnet.private[0], aws_route_table.privateroutetable]
}


output "vpc_id" {
    value = can(var.vpc.vpc_cidr) ? aws_vpc.vpc[0].id : var.vpc_id
}

output "vpc_public_subnet_id" {
    value = can(var.vpc.vpc_cidr) ? aws_subnet.public[0].id : var.vpc_public_subnet_id
}

output "vpc_private_subnet_id" {
    value = can(var.vpc.vpc_cidr) ? aws_subnet.private[0].id : var.vpc_private_subnet_id
}