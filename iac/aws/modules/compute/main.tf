# ============================================================================
# modules/compute/main.tf - Single EC2 Instance
# Region: sa-east-1 (São Paulo, Brazil)
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# SSH KEY PAIR - Auto-generated
# ============================================================================

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = var.tags

  lifecycle {
    ignore_changes = [public_key]
  }
}

# ============================================================================
# ELASTIC IP - STATIC IP (Manager)
# ============================================================================

resource "aws_eip" "manager" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-manager-eip"
    Role = "Manager"
  })
}

# ============================================================================
# ELASTIC IP - STATIC IP (Workers, only when instance_count > 1)
# ============================================================================

resource "aws_eip" "worker" {
  count  = var.instance_count > 1 ? var.instance_count - 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker-${count.index + 1}-eip"
    Role = "Worker"
  })
}

# ============================================================================
# USER DATA SCRIPT
# ============================================================================

locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))
}

# ============================================================================
# EC2 INSTANCE - Manager (always created)
# ============================================================================

resource "aws_instance" "manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.security_group_ids.main]

  user_data = local.user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${local.name_prefix}-manager-root-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-manager"
    Type = "application-server"
    Role = "Manager"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# EC2 INSTANCE - Workers (only when instance_count > 1)
# ============================================================================

resource "aws_instance" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.public_subnet_ids[0] # Use same subnet as manager for AZ compatibility
  vpc_security_group_ids = [var.security_group_ids.main]

  user_data = local.user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${local.name_prefix}-worker-${count.index + 1}-root-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker-${count.index + 1}"
    Type = "application-server"
    Role = "Worker"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# ELASTIC IP ASSOCIATION - Manager
# ============================================================================

resource "aws_eip_association" "manager" {
  instance_id   = aws_instance.manager.id
  allocation_id = aws_eip.manager.id
}

# ============================================================================
# ELASTIC IP ASSOCIATION - Workers
# ============================================================================

resource "aws_eip_association" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  instance_id   = aws_instance.worker[count.index].id
  allocation_id = aws_eip.worker[count.index].id
}