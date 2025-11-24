# ============================================================================
# modules/compute/variables.tf - Single Instance Configuration
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Map of security group IDs"
  type = object({
    main = string
  })
}

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
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}