# ============================================================================
# modules/compute/outputs.tf - Multi-Instance Outputs
# ============================================================================

# Manager Instance Outputs
output "manager_instance_id" {
  description = "ID of the manager EC2 instance"
  value       = aws_instance.manager.id
}

output "manager_public_ip" {
  description = "Public IP of the manager instance"
  value       = aws_eip.manager.public_ip
}

output "manager_private_ip" {
  description = "Private IP of the manager instance"
  value       = aws_instance.manager.private_ip
}

# Worker Instance Outputs
output "worker_instance_ids" {
  description = "IDs of the worker EC2 instances"
  value       = aws_instance.worker[*].id
}

output "worker_public_ips" {
  description = "Public IPs of the worker instances"
  value       = aws_eip.worker[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of the worker instances"
  value       = aws_instance.worker[*].private_ip
}

# Legacy outputs for backwards compatibility (points to manager)
output "instance_id" {
  description = "ID of the primary EC2 instance (manager)"
  value       = aws_instance.manager.id
}

output "instance_public_ip" {
  description = "Public IP of the primary instance (manager)"
  value       = aws_eip.manager.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the primary instance (manager)"
  value       = aws_instance.manager.private_ip
}

output "elastic_ip_id" {
  description = "Allocation ID of the manager Elastic IP"
  value       = aws_eip.manager.id
}

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.main.key_name
}

output "availability_zone" {
  description = "Availability zone of the manager instance"
  value       = aws_instance.manager.availability_zone
}

output "ssh_private_key" {
  description = "Generated SSH private key"
  value       = tls_private_key.main.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Generated SSH public key"
  value       = tls_private_key.main.public_key_openssh
}

# Deployment Mode
output "deployment_mode" {
  description = "Deployment mode (compose or swarm)"
  value       = var.instance_count == 1 ? "compose" : "swarm"
}

output "instance_count" {
  description = "Total number of instances deployed"
  value       = var.instance_count
}
