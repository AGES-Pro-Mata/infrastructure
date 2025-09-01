# Generated from envs/dev/.env
# Mon 01 Sep 2025 07:46:59 AM -03

# Azure Configuration
environment = "dev"
project_name = "myproject"
env_color = "blue                          # Para UI diferenciada"
env_prefix = "dev"
domain_name = "example.com"
subdomain_prefix = "dev                    # dev.promata.com.br"
api_subdomain = "api-dev                   # api-dev.promata.com.br  "
admin_subdomain = "admin-dev               # admin-dev.promata.com.br"
azure_resource_group = "myproject-dev-rg"
azure_subscription_id = "PLACEHOLDER_REPLACE_WITH_YOUR_SUBSCRIPTION_ID"
azure_location = "eastus2"
vm_size = "Standard_B2s                    # Menor para dev"
backend_image = "YOUR_DOCKERHUB_ORG/myproject-backend-dev:latest"
frontend_image = "YOUR_DOCKERHUB_ORG/myproject-frontend-dev:latest"
replicas = "1                              # Apenas 1 réplica para dev"
postgres_db = "myproject_dev"
database_size = "Basic                     # Menor para dev"
monitoring_enabled = "true"
prometheus_retention = "7d                 # Menor retenção"
# DNS/Cloudflare Configuration (if needed)
cloudflare_api_token = "PLACEHOLDER_REPLACE_WITH_YOUR_API_TOKEN"
server_public_ip = "0.0.0.0"             # PLACEHOLDER - Will be updated automatically by Terraform
cloudflare_zone_id = "PLACEHOLDER_REPLACE_WITH_YOUR_ZONE_ID"
create_dns_records = "false"              # Disable until real IPs are available
