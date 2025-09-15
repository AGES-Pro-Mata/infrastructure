# ============================================================================
# modules/security/main.tf
# ============================================================================
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# SECURITY GROUP - MANAGER NODE
# ============================================================================
resource "aws_security_group" "manager" {
  name_prefix = "${local.name_prefix}-manager-"
  vpc_id      = var.vpc_id

  description = "Security group for Docker Swarm manager node"

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

  # Traefik Dashboard
  ingress {
    description = "Traefik Dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Grafana
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Node Exporter
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Postgres Exporter
  ingress {
    description = "Postgres Exporter"
    from_port   = 9187
    to_port     = 9187
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Docker Swarm - Manager
  ingress {
    description = "Docker Swarm Manager"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Docker Swarm - Communication
  ingress {
    description = "Docker Swarm Communication"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Docker Swarm Communication UDP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Docker Swarm - Overlay Network
  ingress {
    description = "Docker Swarm Overlay"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
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
    Name = "${local.name_prefix}-manager-sg"
    Role = "manager"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# SECURITY GROUP - WORKER NODE
# ============================================================================
resource "aws_security_group" "worker" {
  name_prefix = "${local.name_prefix}-worker-"
  vpc_id      = var.vpc_id

  description = "Security group for Docker Swarm worker node"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (for applications)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (for applications)
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

  # Prisma Studio
  ingress {
    description = "Prisma Studio"
    from_port   = 5555
    to_port     = 5555
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Node Exporter
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Postgres Exporter
  ingress {
    description = "Postgres Exporter"
    from_port   = 9187
    to_port     = 9187
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Docker Swarm - Communication
  ingress {
    description = "Docker Swarm Communication"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Docker Swarm Communication UDP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Docker Swarm - Overlay Network
  ingress {
    description = "Docker Swarm Overlay"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
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
    Name = "${local.name_prefix}-worker-sg"
    Role = "worker"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# SECURITY GROUP - DATABASE
# ============================================================================
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-database-"
  vpc_id      = var.vpc_id

  description = "Security group for database access"

  # PostgreSQL from application security groups
  ingress {
    description     = "PostgreSQL from manager"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.manager.id]
  }

  ingress {
    description     = "PostgreSQL from worker"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker.id]
  }

  # PostgreSQL replica port
  ingress {
    description     = "PostgreSQL Replica from manager"
    from_port       = 5433
    to_port         = 5433
    protocol        = "tcp"
    security_groups = [aws_security_group.manager.id]
  }

  ingress {
    description     = "PostgreSQL Replica from worker"
    from_port       = 5433
    to_port         = 5433
    protocol        = "tcp"
    security_groups = [aws_security_group.worker.id]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-database-sg"
    Role = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# NOTA: IAM roles e Secrets Manager removidos conforme diagrama original
# As instâncias EC2 operarão sem perfis IAM específicos
# Secrets serão gerenciados via variáveis de ambiente ou arquivos de configuração
# ============================================================================