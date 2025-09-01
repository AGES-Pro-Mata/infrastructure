# Common module variables for Pro-Mata infrastructure

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "pro-mata"
}

variable "environment_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Pro-Mata"
    ManagedBy   = "Terraform"
  }
}

# Domain configuration
variable "base_domain" {
  description = "Base domain for the environment"
  type        = string
  default     = "duckdns.org"
}

# Docker configuration
variable "docker_registry" {
  description = "Docker registry URL"
  type        = string
  default     = "docker.io"
}

variable "docker_namespace" {
  description = "Docker namespace/organization"
  type        = string
  default     = "norohim"
}