# ============================================================================
# modules/compute/main.tf
# ============================================================================
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
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# SSH KEY PAIR
# ============================================================================
resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = var.ssh_public_key

  tags = var.tags
}

# ============================================================================
# ELASTIC IPS - STATIC IPS (Similar to Azure Static IPs)
# ============================================================================
resource "aws_eip" "manager" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-manager-eip"
    Role = "manager"
  })
}

resource "aws_eip" "worker" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker-eip"
    Role = "worker"
  })
}

# ============================================================================
# USER DATA SCRIPT - MANAGER NODE
# ============================================================================
locals {
  manager_user_data = base64encode(templatefile("${path.module}/user_data_manager.sh", {
    project_name = var.project_name
    environment  = var.environment
    worker_ip    = aws_eip.worker.public_ip
  }))
}

# ============================================================================
# USER DATA SCRIPT - WORKER NODE
# ============================================================================
locals {
  worker_user_data = base64encode(templatefile("${path.module}/user_data_worker.sh", {
    project_name = var.project_name
    environment  = var.environment
    manager_ip   = aws_eip.manager.public_ip
  }))
}

# ============================================================================
# EC2 INSTANCE - MANAGER NODE
# ============================================================================
resource "aws_instance" "manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.manager_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.security_group_ids.manager]

  user_data = local.manager_user_data

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
    Role = "manager"
    Type = "swarm-manager"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# EC2 INSTANCE - WORKER NODE
# ============================================================================
resource "aws_instance" "worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.security_group_ids.worker]

  user_data = local.worker_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ebs_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${local.name_prefix}-worker-root-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker"
    Role = "worker"
    Type = "swarm-worker"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# ELASTIC IP ASSOCIATIONS
# ============================================================================
resource "aws_eip_association" "manager" {
  instance_id   = aws_instance.manager.id
  allocation_id = aws_eip.manager.id
}

resource "aws_eip_association" "worker" {
  instance_id   = aws_instance.worker.id
  allocation_id = aws_eip.worker.id
}

# ============================================================================
# ADDITIONAL EBS VOLUMES FOR DATA (Optional)
# ============================================================================
resource "aws_ebs_volume" "manager_data" {
  availability_zone = aws_instance.manager.availability_zone
  size              = 30
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-manager-data-volume"
  })
}

resource "aws_ebs_volume" "worker_data" {
  availability_zone = aws_instance.worker.availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker-data-volume"
  })
}

resource "aws_volume_attachment" "manager_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.manager_data.id
  instance_id = aws_instance.manager.id
}

resource "aws_volume_attachment" "worker_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.worker_data.id
  instance_id = aws_instance.worker.id
}