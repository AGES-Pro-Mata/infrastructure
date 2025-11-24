# ============================================================================
# modules/email/variables.tf
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
  description = "Domain name for SES"
  type        = string
}

variable "admin_email" {
  description = "Administrator email"
  type        = string
}

variable "ses_email_list" {
  description = "List of emails to verify in SES"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
