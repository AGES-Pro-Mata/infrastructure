# Generated from envs/prod/.env
# Mon 01 Sep 2025 04:45:52 PM -03

# AWS Configuration
aws_region = "us-east-1"
environment = "prod"
project_name = "pro-mata"
vpc_cidr = "10.0.0.0/16"
env_color = "red                           # Para UI diferenciada"
env_prefix = "prod"
domain_name = "promata.com.br"
subdomain_prefix = "www                    # www.promata.com.br"
api_subdomain = "api                       # api.promata.com.br"
admin_subdomain = "admin                   # admin.promata.com.br"
azure_resource_group = "pro-mata-prod-rg"
azure_subscription_id = "PLACEHOLDER_REPLACE_WITH_YOUR_SUBSCRIPTION_ID"
azure_location = "eastus2"
vm_size = "Standard_D2s_v3                # Maior para prod"
backend_image = "norohim/pro-mata-backend:latest"
frontend_image = "norohim/pro-mata-frontend:latest"
replicas = "3                              # Múltiplas réplicas para prod"
postgres_db = "promata_prod"
database_size = "Standard                  # Maior para prod"
monitoring_enabled = "true"
prometheus_retention = "30d                # Maior retenção"
# ECS Configuration
ecs_task_cpu = "1024"                      # Higher for prod
ecs_task_memory = "2048"                   # Higher for prod

# DNS/Cloudflare Configuration
cloudflare_api_token = "PLACEHOLDER_REPLACE_WITH_YOUR_API_TOKEN"
server_public_ip = "1.1.1.1"             # PLACEHOLDER - Update with actual AWS Elastic IP
cloudflare_zone_id = "PLACEHOLDER_REPLACE_WITH_YOUR_ZONE_ID"
create_dns_records = "false"              # Disable until real IPs are available