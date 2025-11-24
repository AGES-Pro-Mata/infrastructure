# ============================================================================
# modules/security/main.tf - Single Instance Security Group
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# SECURITY GROUP - APPLICATION SERVER
# ============================================================================

resource "aws_security_group" "main" {
  name_prefix = "${local.name_prefix}-"
  vpc_id      = var.vpc_id

  description = "Security group for application server"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application ports
  ingress {
    description = "Application Port Range"
    from_port   = 3000
    to_port     = 3010
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # PostgreSQL
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5433
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Traefik Dashboard (optional)
  ingress {
    description = "Traefik Dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}