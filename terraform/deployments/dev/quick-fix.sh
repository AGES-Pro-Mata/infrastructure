#!/bin/bash

# Quick DNS Fix - Disable Cloudflare DNS temporarily
echo "🔧 Quick DNS Fix - Disable Cloudflare temporarily"
echo "================================================="

# Create terraform.tfvars with Cloudflare disabled
cat > terraform.tfvars << 'EOF'
# Pro-Mata Development Environment - DNS Disabled Mode

# Project Configuration
project_name = "pro-mata"
environment = "dev"
domain_name = "promata.com.br"

# Azure Configuration
resource_group_name = "rg-pro-mata-dev"
storage_account_name = "promatadevstg"
location = "East US 2"
vm_size = "Standard_B2s"

# Disable Cloudflare DNS for now
enable_cloudflare_dns = false
cloudflare_api_token = null
cloudflare_zone_id = null

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
EOF

echo "✅ Created terraform.tfvars with Cloudflare DNS disabled"
echo ""
echo "🚀 Now you can run:"
echo "   terraform plan   # Should work without Cloudflare errors"
echo "   terraform apply  # Will update existing infrastructure"
echo ""
echo "💡 This approach:"
echo "   ✅ Fixes variable mismatches"
echo "   ✅ Prevents infrastructure recreation"
echo "   ✅ Skips DNS setup for now"
echo ""
echo "   Later, you can:"
echo "   1. Get Cloudflare API credentials"
echo "   2. Set enable_cloudflare_dns = true"
echo "   3. Run terraform apply again for DNS"
