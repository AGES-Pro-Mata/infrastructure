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

variable "manager_public_ip" {
  description = "Public IP of the manager node"
  type        = string
}

variable "worker_public_ip" {
  description = "Public IP of the worker node"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
