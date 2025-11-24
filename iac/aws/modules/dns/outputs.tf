# ============================================================================
# modules/dns/outputs.tf
# ============================================================================

output "dns_records" {
  description = "Created DNS records"
  value = {
    for k, v in cloudflare_record.services : k => {
      name    = v.name
      content = v.content
      type    = v.type
      proxied = v.proxied
    }
  }
}

output "environment_subdomain" {
  description = "Environment-specific subdomain (if created)"
  value       = var.environment != "prod" ? "${var.environment}.${var.domain_name}" : null
}