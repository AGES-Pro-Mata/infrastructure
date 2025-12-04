# ============================================================================
# outputs.tf
# ============================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = module.compute.instance_public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance"
  value       = module.compute.instance_private_ip
}

output "instance_id" {
  description = "Instance ID of the EC2 instance"
  value       = module.compute.instance_id
}

output "s3_bucket_names" {
  description = "Names of created S3 buckets"
  value       = module.storage.s3_bucket_name
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
  description = "Created DNS records (if Cloudflare is enabled)"
  value       = var.enable_cloudflare ? module.dns[0].dns_records : null
}

output "security_group_ids" {
  description = "Security group IDs"
  value       = module.security.security_group_ids
}

# Deployment Mode
output "deployment_mode" {
  description = "Deployment mode (compose or swarm)"
  value       = module.compute.deployment_mode
}

output "instance_count" {
  description = "Total number of instances"
  value       = module.compute.instance_count
}

# Manager and Worker IPs
output "manager_public_ip" {
  description = "Public IP of manager instance"
  value       = module.compute.manager_public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker instances"
  value       = module.compute.worker_public_ips
}

# Connection information for Ansible
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    deployment_mode = module.compute.deployment_mode
    instance_count  = module.compute.instance_count
    manager = {
      public_ip   = module.compute.manager_public_ip
      private_ip  = module.compute.manager_private_ip
      instance_id = module.compute.manager_instance_id
    }
    workers = {
      public_ips   = module.compute.worker_public_ips
      private_ips  = module.compute.worker_private_ips
      instance_ids = module.compute.worker_instance_ids
    }
  }
}

# Environment configuration
output "environment_config" {
  description = "Environment configuration for applications"
  value = {
    environment     = var.environment
    domain_name     = var.domain_name
    aws_region      = var.aws_region
    deployment_mode = module.compute.deployment_mode
    instance_count  = module.compute.instance_count
    manager_ip      = module.compute.manager_public_ip
    worker_ips      = module.compute.worker_public_ips
    s3_buckets      = module.storage.s3_bucket_name
    ses_endpoint    = module.email.ses_smtp_endpoint
  }
}

# Static Assets Bucket (S3)
output "static_assets_bucket" {
  description = "S3 bucket for frontend static assets"
  value       = module.storage.s3_bucket_name
}

output "s3_website_endpoint" {
  description = "S3 static website endpoint for nginx proxy"
  value       = module.storage.s3_website_endpoint
}

output "s3_website_domain" {
  description = "S3 static website domain for nginx proxy configuration"
  value       = module.storage.s3_website_domain
}

# Cloudflare Status
output "cloudflare_enabled" {
  description = "Whether Cloudflare DNS management is enabled"
  value       = var.enable_cloudflare
}

# SSH Keys
output "ssh_private_key" {
  description = "Private SSH key for connecting to instances"
  value       = module.compute.ssh_private_key
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key"
  value       = module.compute.ssh_public_key
}