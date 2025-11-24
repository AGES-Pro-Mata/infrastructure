# Global variables for all environments
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "promata"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region or AWS region"
  type        = string
}

# Azure-specific variables
variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "East US 2"
}

variable "azure_vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

# Cloudflare variables
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for promata.com.br"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "promata.com.br"
}

# Security variables (will be overridden by vault)
variable "admin_ssh_key" {
  description = "SSH public key for admin access"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

# Network variables
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Should be restricted in production
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed for HTTP/HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Feature flags
variable "enable_monitoring" {
  description = "Enable monitoring with Prometheus and Grafana"
  type        = bool
  default     = true
}

variable "enable_cloudflare_dns" {
  description = "Enable Cloudflare DNS management"
  type        = bool
  default     = true
}

variable "enable_ssl_certificates" {
  description = "Enable automatic SSL certificate management"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

# Tagging
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "promata"
    Team      = "ages"
    ManagedBy = "terraform"
  }
}