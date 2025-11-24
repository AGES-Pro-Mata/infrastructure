terraform {
  backend "azurerm" {
    resource_group_name  = "rg-promata-terraform-dev"
    storage_account_name = "promatadevterraform"
    container_name       = "terraform-state"
    key                  = "dev/infrastructure.tfstate"
  }
}