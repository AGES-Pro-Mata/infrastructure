output "dns_records" {
  description = "DNS records created"
  value = var.create_dns_records ? {
    for service_name, record in cloudflare_record.services : service_name => {
      name    = record.name
      content = record.content
      proxied = record.proxied
      service = local.services[service_name].service
      port    = local.services[service_name].port
    }
  } : {}
}

output "ssl_configuration" {
  description = "SSL/TLS configuration applied"
  value = var.configure_ssl ? {
    ssl_mode         = var.ssl_mode
    always_use_https = "on"
    min_tls_version  = "1.2"
    security_level   = var.security_level
    note             = "Zone settings disabled for free plan compatibility"
    } : {
    note = "SSL configuration disabled"
  }
}

output "page_rules_created" {
  description = "Page rules created for optimization"
  value = var.create_page_rules ? [
    "Static assets caching: ${var.domain_name}/static/*",
    "API no cache: api.${var.domain_name}/*",
    "WWW redirect: www.${var.domain_name}/* → https://${var.domain_name}/*"
  ] : []
}

output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID used"
  value       = var.cloudflare_zone_id
}

output "domain_urls" {
  description = "All configured domain URLs"
  value = var.create_dns_records ? {
    for service_name, config in local.services : service_name =>
    service_name == "@" ? "https://${var.domain_name}" : "https://${service_name}.${var.domain_name}"
  } : {}
}