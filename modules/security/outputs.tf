# ============================================================================
# modules/security/outputs.tf
# ============================================================================
output "security_group_ids" {
  description = "Map of security group IDs"
  value = {
    manager  = aws_security_group.manager.id
    worker   = aws_security_group.worker.id
    database = aws_security_group.database.id
  }
}

output "manager_security_group_id" {
  description = "Security group ID for manager node"
  value       = aws_security_group.manager.id
}

output "worker_security_group_id" {
  description = "Security group ID for worker node"
  value       = aws_security_group.worker.id
}

output "database_security_group_id" {
  description = "Security group ID for database"
  value       = aws_security_group.database.id
}

# ============================================================================
# NOTA: Outputs de IAM e Secrets Manager removidos
# ============================================================================