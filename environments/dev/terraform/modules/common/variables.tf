# Add to terraform/modules/common/variables.tf
variable "environment_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Pro-Mata"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}