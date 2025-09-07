# Generated from config.sh
# Tue 02 Sep 2025 03:46:47 AM -03

# Azure Configuration
environment = "dev"
project_name = "pro-mata"
domain_name = "promata.com.br"
resource_group_name = "rg-myproject-dev"
location = "East US 2"
vm_size = "Standard_B2s"

# Application Images
backend_image = "norohim/pro-mata-backend-dev:latest"
frontend_image = "norohim/pro-mata-frontend-dev:latest"
migration_image = "norohim/pro-mata-database-dev:latest"

# Replicas
backend_replicas = 1
frontend_replicas = 1

# Database
postgres_db = "promata_dev"
postgres_user = "promata"

# Storage (will be made unique automatically)
storage_account_name = "promatadevstg"

# Cloudflare (optional)
cloudflare_api_token = "oycrpCKXpVQmDq_6V2ArnidSxImWxvkzJhxhhBtl"
cloudflare_zone_id = "c59ab9e254cc4d555f265d1d111f95ed"
enable_cloudflare_dns = true
create_page_rules = false

# Monitoring
monitoring_enabled = true

# Tags
common_tags = {
  Project     = "pro-mata"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "pro-mata-team"
}
