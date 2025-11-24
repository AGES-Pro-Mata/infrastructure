output "dns_records" {
  description = "DNS records created"
  value = var.create_dns_records ? {
    main = {
      name    = cloudflare_record.main[0].name
      content = cloudflare_record.main[0].content
      proxied = cloudflare_record.main[0].proxied
    }
    www = {
      name    = cloudflare_record.www[0].name
      content = cloudflare_record.www[0].content
      proxied = cloudflare_record.www[0].proxied
    }
    api = {
      name    = cloudflare_record.api[0].name
      content = cloudflare_record.api[0].content
      proxied = cloudflare_record.api[0].proxied
    }
    traefik = {
      name    = cloudflare_record.traefik[0].name
      content = cloudflare_record.traefik[0].content
      proxied = cloudflare_record.traefik[0].proxied
    }
    pgadmin = {
      name    = cloudflare_record.pgadmin[0].name
      content = cloudflare_record.pgadmin[0].content
      proxied = cloudflare_record.pgadmin[0].proxied
    }
  } : {}
}

output "ssl_configuration" {
  description = "SSL/TLS configuration applied"
  value = var.configure_ssl ? {
    ssl_mode         = cloudflare_zone_settings_override.ssl_settings[0].settings[0].ssl
    always_use_https = cloudflare_zone_settings_override.ssl_settings[0].settings[0].always_use_https
    min_tls_version  = cloudflare_zone_settings_override.ssl_settings[0].settings[0].min_tls_version
    tls_1_3          = cloudflare_zone_settings_override.ssl_settings[0].settings[0].tls_1_3
  } : {}
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
    main        = "https://${var.domain_name}"
    www         = "https://www.${var.domain_name}"
    api         = "https://api.${var.domain_name}"
    traefik     = "https://traefik.${var.domain_name}"
    pgadmin     = "https://pgadmin.${var.domain_name}"
    environment = var.environment != "prod" ? "https://${var.environment}.${var.domain_name}" : null
  } : {}
}