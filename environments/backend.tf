# Terraform Backend Configuration - Pro-Mata Infrastructure
# Generated automatically by backend-setup.sh

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-promata-terraform-state"
    storage_account_name = "promatatfstate66108"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
    use_azuread_auth     = true
  }
}
