# ============================================================================
# variables.tf
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "promata"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
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
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "ebs_volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 19
}

variable "instance_count" {
  description = "Number of EC2 instances (1 for Compose, 2+ for Swarm)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1"
  }
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (1 for cost savings, 3 for high availability)"
  type        = number
  default     = 1

  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= 3
    error_message = "nat_gateway_count must be between 1 and 3"
  }
}

# Cloudflare
variable "enable_cloudflare" {
  description = "Enable Cloudflare DNS management (set to false to skip DNS module entirely)"
  type        = bool
  default     = true
}

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

variable "enable_frontend_s3_proxy" {
  description = "Enable Cloudflare page rule to proxy root domain to S3 frontend bucket"
  type        = bool
  default     = false
}

# variable "use_cloudfront" {
#   description = "Use CloudFront for root and www domains (managed by another team)"
#   type        = bool
#   default     = false
# }

# variable "cloudfront_domain_name" {
#   description = "CloudFront distribution domain name (e.g., d111111abcdef8.cloudfront.net)"
#   type        = string
#   default     = ""
# }

# Email configuration
variable "admin_email" {
  description = "Administrator email for SES and notifications"
  type        = string
  default     = "admin@promata.com.br"
}

variable "ses_email_list" {
  description = "List of emails to verify in SES"
  type        = list(string)
  default = [
    "admin@promata.com.br",
    "noreply@promata.com.br",
    "support@promata.com.br"
  ]
}