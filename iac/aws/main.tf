


# ============================================================================
# main.tf - Pro-Mata AWS Infrastructure
# ============================================================================
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "terraform"
    Owner       = var.owner
  }

  name_prefix = "${var.project_name}-prod"
}

# ============================================================================
# NETWORKING MODULE
# ============================================================================
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = "prod"
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
  nat_gateway_count  = var.nat_gateway_count

  tags = local.common_tags
}

# ============================================================================
# SECURITY MODULE
# ============================================================================
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = "prod"
  vpc_id       = module.networking.vpc_id

  tags = local.common_tags
}

# ============================================================================
# STORAGE MODULE
# ============================================================================
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = "prod"

  tags = local.common_tags
}

# ============================================================================
# COMPUTE MODULE - EC2 Instances (1 for Compose, 2+ for Swarm)
# ============================================================================
module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  environment        = "prod"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_ids = module.security.security_group_ids
  instance_type      = var.instance_type
  ebs_volume_size    = var.ebs_volume_size
  instance_count     = var.instance_count

  tags = local.common_tags
}

# ============================================================================
# EMAIL SERVICE MODULE (SES)
# ============================================================================
module "email" {
  source = "./modules/email"

  project_name   = var.project_name
  environment    = "prod"
  domain_name    = var.domain_name
  admin_email    = var.admin_email
  ses_email_list = var.ses_email_list

  tags = local.common_tags
}

# ============================================================================
# DNS MODULE (CLOUDFLARE) - Optional
# ============================================================================

module "dns" {
  source = "./modules/dns"
  count  = var.enable_cloudflare ? 1 : 0

  project_name             = var.project_name
  environment              = "prod"
  domain_name              = var.domain_name
  cloudflare_zone_id       = var.cloudflare_zone_id
  instance_public_ip       = module.compute.instance_public_ip
  aws_region               = var.aws_region
  enable_frontend_s3_proxy = var.enable_frontend_s3_proxy

  tags = local.common_tags
}

# ============================================================================
# NOTE: Terraform state is stored in Azure Storage Account
# No need for S3 backend or DynamoDB table for state management
# ============================================================================
