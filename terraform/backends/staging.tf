terraform {
  backend "azurerm" {
    resource_group_name  = "rg-promata-terraform-staging"
    storage_account_name = "promatastgterraform"
    container_name       = "terraform-state"  
    key                 = "staging/infrastructure.tfstate"
  }
}