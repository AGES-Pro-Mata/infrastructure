# ============================================================================
# modules/compute/variables.tf
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

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Map of security group IDs"
  type = object({
    manager  = string
    worker   = string
    database = string
  })
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}

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

# ============================================================================
# NOTA: ec2_instance_profile_name removido - não usando IAM instance profiles
# ============================================================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# modules/compute/outputs.tf
# ============================================================================
output "manager_instance_id" {
  description = "ID of the manager instance"
  value       = aws_instance.manager.id
}

output "worker_instance_id" {
  description = "ID of the worker instance"
  value       = aws_instance.worker.id
}

output "manager_public_ip" {
  description = "Public IP of the manager instance"
  value       = aws_eip.manager.public_ip
}

output "manager_private_ip" {
  description = "Private IP of the manager instance"
  value       = aws_instance.manager.private_ip
}

output "worker_public_ip" {
  description = "Public IP of the worker instance"
  value       = aws_eip.worker.public_ip
}

output "worker_private_ip" {
  description = "Private IP of the worker instance"
  value       = aws_instance.worker.private_ip
}

output "manager_elastic_ip_id" {
  description = "Allocation ID of the manager Elastic IP"
  value       = aws_eip.manager.id
}

output "worker_elastic_ip_id" {
  description = "Allocation ID of the worker Elastic IP"
  value       = aws_eip.worker.id
}

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.main.key_name
}

output "manager_availability_zone" {
  description = "Availability zone of the manager instance"
  value       = aws_instance.manager.availability_zone
}

output "worker_availability_zone" {
  description = "Availability zone of the worker instance"
  value       = aws_instance.worker.availability_zone
}