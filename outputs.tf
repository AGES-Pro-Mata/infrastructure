# ============================================================================
# outputs.tf
# ============================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "manager_public_ip" {
  description = "Public IP of the manager node"
  value       = module.compute.manager_public_ip
}

output "manager_private_ip" {
  description = "Private IP of the manager node"
  value       = module.compute.manager_private_ip
}

output "worker_public_ip" {
  description = "Public IP of the worker node"
  value       = module.compute.worker_public_ip
}

output "worker_private_ip" {
  description = "Private IP of the worker node"
  value       = module.compute.worker_private_ip
}

output "manager_instance_id" {
  description = "Instance ID of the manager node"
  value       = module.compute.manager_instance_id
}

output "worker_instance_id" {
  description = "Instance ID of the worker node"
  value       = module.compute.worker_instance_id
}

output "s3_bucket_names" {
  description = "Names of created S3 buckets"
  value       = module.storage.s3_bucket_names
}

output "ses_domain_identity" {
  description = "SES domain identity"
  value       = module.email.ses_domain_identity
}

output "ses_smtp_endpoint" {
  description = "SES SMTP endpoint"
  value       = module.email.ses_smtp_endpoint
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.dns.dns_records
}

output "security_group_ids" {
  description = "Security group IDs"
  value       = module.security.security_group_ids
}

# Connection information for Ansible
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    manager = {
      public_ip  = module.compute.manager_public_ip
      private_ip = module.compute.manager_private_ip
      instance_id = module.compute.manager_instance_id
    }
    worker = {
      public_ip  = module.compute.worker_public_ip
      private_ip = module.compute.worker_private_ip
      instance_id = module.compute.worker_instance_id
    }
  }
}

# Environment configuration
output "environment_config" {
  description = "Environment configuration for applications"
  value = {
    environment    = var.environment
    domain_name    = var.domain_name
    aws_region     = var.aws_region
    manager_ip     = module.compute.manager_public_ip
    worker_ip      = module.compute.worker_public_ip
    s3_buckets     = module.storage.s3_bucket_names
    ses_endpoint   = module.email.ses_smtp_endpoint
  }
}