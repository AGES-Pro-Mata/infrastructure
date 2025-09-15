# ============================================================================
# providers.tf
# ============================================================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "promata-terraform-state-backend"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "promata-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}