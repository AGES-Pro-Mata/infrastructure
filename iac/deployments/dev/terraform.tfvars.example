# Pro-Mata Development Environment Variables
# Copy this file to terraform.tfvars and update with actual values

# Project Configuration
project_name = "pro-mata"
environment = "dev"
domain_name = "promata.com.br"

# Azure Configuration
resource_group_name = "rg-pro-mata-dev"
storage_account_name = "promatadevstg"
location = "East US 2"
vm_size = "Standard_B2s"  # Keep current size to avoid recreation

# Cloudflare Configuration (Required for DNS)
cloudflare_api_token = "YOUR_CLOUDFLARE_API_TOKEN_HERE"
cloudflare_zone_id = "YOUR_CLOUDFLARE_ZONE_ID_HERE"
enable_cloudflare_dns = true

# Application Configuration
backend_image = "norohim/pro-mata-backend-dev:latest"
frontend_image = "norohim/pro-mata-frontend-dev:latest"
migration_image = "norohim/pro-mata-migration-dev:latest"

# Database Configuration
postgres_db = "promata_dev"
postgres_user = "promata"

# Tags
common_tags = {
  Project     = "pro-mata"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "pro-mata-team"
}

# Disable features that might cause issues
create_page_rules = false
monitoring_enabled = true
