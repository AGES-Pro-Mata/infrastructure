# ============================================================================
# modules/storage/variables.tf
# ============================================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region for S3 website endpoint URL"
  type        = string
  default     = "sa-east-1"
}