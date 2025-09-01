# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({ Name = "${local.prefix}-vpc" }, local.common_tags)
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge({ Name = "${local.prefix}-igw" }, local.common_tags)
}

# Subnet Pública
resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = merge({ Name = "${local.prefix}-public-subnet" }, local.common_tags)
}

# Subnet Privada
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1a"

  tags = merge({ Name = "${local.prefix}-private-subnet" }, local.common_tags)
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge({ Name = "${local.prefix}-eip-natgw" }, local.common_tags)
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge({ Name = "${local.prefix}-nat-gw" }, local.common_tags)

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge({ Name = "rt-public-${local.prefix}" }, local.common_tags)
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge({ Name = "rt-private-${local.prefix}" }, local.common_tags)
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# VPC Endpoint Gateway para S3
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  # Route tables donde se añadirán las rutas al endpoint
  route_table_ids = [aws_route_table.private.id]
  tags            = merge({ Name = "${local.prefix}-s3-vpc-endpoint" }, local.common_tags)
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  log_destination          = data.aws_s3_bucket.anomaly-detection-flow-logs.arn
  log_destination_type     = "s3"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = 60
  log_format               = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

  tags = merge({ Name = "vpc-flowlog-${local.prefix}" }, local.common_tags)
}
