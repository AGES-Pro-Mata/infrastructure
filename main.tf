


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
# COMPUTE MODULE
# ============================================================================
module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  environment               = "prod"
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  private_subnet_ids        = module.networking.private_subnet_ids
  security_group_ids        = module.security.security_group_ids
  ssh_public_key            = var.ssh_public_key
  manager_instance_type     = var.manager_instance_type
  worker_instance_type      = var.worker_instance_type
  ebs_volume_size           = var.ebs_volume_size

  tags = local.common_tags
}

# ============================================================================
# EMAIL SERVICE MODULE (SES)
# ============================================================================
module "email" {
  source = "./modules/email"

  project_name    = var.project_name
  environment     = "prod"
  domain_name     = var.domain_name
  admin_email     = var.admin_email
  ses_email_list  = var.ses_email_list

  tags = local.common_tags
}

# ============================================================================
# DNS MODULE (CLOUDFLARE)
# ============================================================================
module "dns" {
  source = "./modules/dns"

  project_name          = var.project_name
  environment           = "prod"
  domain_name           = var.domain_name
  cloudflare_zone_id    = var.cloudflare_zone_id
  manager_public_ip     = module.compute.manager_public_ip
  worker_public_ip      = module.compute.worker_public_ip

  tags = local.common_tags
}

# ============================================================================
# TERRAFORM STATE BACKEND SETUP
# ============================================================================
module "terraform_backend" {
  source = "./modules/terraform_backend"

  project_name = var.project_name
  environment  = "prod"
  aws_region   = var.aws_region

  tags = local.common_tags
}
