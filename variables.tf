# ============================================================================
# variables.tf
# ============================================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "promata"
}

# ============================================================================
# NOTA: environment fixo como "prod" - removido como variável
# Todos os recursos serão criados como produção
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "pro-mata-team"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "promata.com.br"
}

# Instance configurations
variable "manager_instance_type" {
  description = "EC2 instance type for manager node"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker node"
  type        = string
  default     = "t3.medium"
}

variable "ebs_volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 50
}

# SSH Key
variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}

# Cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
  sensitive   = true
}

# Email configuration
variable "admin_email" {
  description = "Administrator email for SES and notifications"
  type        = string
  default     = "admin@promata.com.br"
}

variable "ses_email_list" {
  description = "List of emails to verify in SES"
  type        = list(string)
  default     = [
    "admin@promata.com.br",
    "noreply@promata.com.br",
    "support@promata.com.br"
  ]
}