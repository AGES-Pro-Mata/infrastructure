# ============================================================================
# modules/security/outputs.tf - Single Security Group
# ============================================================================

output "security_group_ids" {
  description = "Map of security group IDs"
  value = {
    main = aws_security_group.main.id
  }
}

output "main_security_group_id" {
  description = "ID of the main security group"
  value       = aws_security_group.main.id
}