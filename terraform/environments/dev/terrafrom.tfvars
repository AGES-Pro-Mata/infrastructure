# Terraform Variables for Pro-Mata Development Environment

# Basic Configuration
resource_group_name = "rg-promata-dev"
azure_location      = "East US 2"
environment         = "development"
project_name        = "pro-mata"

# VM Configuration
vm_size        = "Standard_B2s"  # 2 vCPU, 4 GB RAM - Good for Azure for Students
admin_username = "promata"

# SSH Key - Will be loaded from environment or CLI
# ssh_public_key = "ssh-rsa YOUR_PUBLIC_KEY_HERE"

# Tags
tags = {
  Environment = "development"
  Project     = "pro-mata"
  ManagedBy   = "terraform"
  CostCenter  = "ages-pucrs"
  Owner       = "dev-team"
  Purpose     = "shared-backend-environment"
}