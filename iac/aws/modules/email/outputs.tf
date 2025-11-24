# ============================================================================
# modules/email/outputs.tf
# ============================================================================

output "ses_domain_identity" {
  description = "SES domain identity"
  value       = aws_ses_domain_identity.main.domain
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

output "ses_smtp_endpoint" {
  description = "SES SMTP endpoint"
  value       = "email-smtp.us-east-2.amazonaws.com"
}

output "ses_smtp_username" {
  description = "SES SMTP username"
  value       = aws_iam_access_key.ses_smtp.id
  sensitive   = true
}

output "ses_smtp_password" {
  description = "SES SMTP password"
  value       = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
  sensitive   = true
}

output "ses_configuration_set" {
  description = "SES configuration set name"
  value       = aws_ses_configuration_set.main.name
}