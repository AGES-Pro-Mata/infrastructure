# ============================================================================
# modules/dns/variables.tf
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "instance_public_ip" {
  description = "Public IP of the instance"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region for S3 website endpoint"
  type        = string
  default     = "us-east-2"
}

variable "enable_frontend_s3_proxy" {
  description = "Enable Cloudflare page rule to proxy root domain to S3 frontend"
  type        = bool
  default     = false
}

# variable "cloudfront_domain_name" {
#   description = "CloudFront distribution domain name (e.g., d111111abcdef8.cloudfront.net)"
#   type        = string
#   default     = ""
# }

# variable "use_cloudfront" {
#   description = "Use CloudFront for root and www domains instead of EC2"
#   type        = bool
#   default     = false
# }
