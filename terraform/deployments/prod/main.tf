# AWS Infrastructure for Production Environment
# Pro-Mata Infrastructure - Production

# VPC
resource "aws_vpc" "prod" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "vpc-promata-prod"
    Environment = "production"
    Project     = "pro-mata"
    ManagedBy   = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
  
  tags = {
    Name        = "igw-promata-prod"
    Environment = "production"
    Project     = "pro-mata"
  }
}

# Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name        = "subnet-promata-prod-private-${count.index + 1}"
    Environment = "production"
    Project     = "pro-mata"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "subnet-promata-prod-public-${count.index + 1}"
    Environment = "production"
    Project     = "pro-mata"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }
  
  tags = {
    Name        = "rt-promata-prod-public"
    Environment = "production"
    Project     = "pro-mata"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

  depends_on = [
    aws_route_table.public,
    aws_subnet.public
  ]
}

# Security Group for ECS
resource "aws_security_group" "ecs" {
  name        = "promata-prod-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.prod.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "promata-prod-ecs-sg"
    Environment = "production"
    Project     = "pro-mata"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "prod" {
  name = "promata-prod"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name        = "ecs-promata-prod"
    Environment = "production"
    Project     = "pro-mata"
  }

  depends_on = [
    aws_subnet.public,
    aws_security_group.ecs
  ]
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}
