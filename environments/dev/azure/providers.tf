# Terraform Providers Configuration for Development Environment
# Azure Resource Manager Provider

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  backend "azurerm" {
    # Backend configuration will be loaded from backend-setup.sh
    # resource_group_name  = "rg-promata-tfstate"
    # storage_account_name = "promatatfstate"
    # container_name       = "tfstate"
    # key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}