# Azure Blob Storage Frontend Module
# Static website hosting para frontend React

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.13"
    }
  }
}

# Storage Account
resource "azurerm_storage_account" "frontend" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  # Enable static website
  static_website {
    index_document     = "index.html"
    error_404_document = "index.html" # SPA routing
  }

  # Enable HTTPS only
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  # Blob properties
  blob_properties {
    cors_rule {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = [
        "https://${var.domain_name}",
        "https://www.${var.domain_name}",
        "https://api.${var.domain_name}",
      ]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3000
    }

    # Versioning
    versioning_enabled = var.enable_versioning

    # Delete retention
    delete_retention_policy {
      days = 7
    }
  }

  tags = merge(var.tags, {
    Name        = var.storage_account_name
    Environment = var.environment
    Purpose     = "Frontend Static Website"
  })
}

# Container for $web (created automatically by static_website, but we manage explicitly)
resource "azurerm_storage_container" "web" {
  name                  = "$web"
  storage_account_name  = azurerm_storage_account.frontend.name
  container_access_type = "blob"
}

# Lifecycle Management (optional - clean old versions)
resource "azurerm_storage_management_policy" "frontend" {
  count              = var.enable_versioning ? 1 : 0
  storage_account_id = azurerm_storage_account.frontend.id

  rule {
    name    = "delete-old-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}
