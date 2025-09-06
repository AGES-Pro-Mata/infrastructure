terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# DNS Records
resource "cloudflare_record" "main" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "@"  # Root domain
  content = var.server_public_ip
  type    = "A"
  ttl     = 1     # Auto TTL
  proxied = var.main_domain_proxied
}

resource "cloudflare_record" "www" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

resource "cloudflare_record" "api" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "api"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.api_proxied
}

resource "cloudflare_record" "traefik" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "traefik"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.traefik_proxied  # Usually false for dashboard
}

resource "cloudflare_record" "pgadmin" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "pgadmin"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

resource "cloudflare_record" "grafana" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

resource "cloudflare_record" "prometheus" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "prometheus"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

resource "cloudflare_record" "metabase" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "metabase"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

resource "cloudflare_record" "analytics" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "analytics"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

# Environment-specific subdomains
resource "cloudflare_record" "environment_subdomain" {
  count   = var.create_dns_records && var.environment != "prod" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.environment
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

# Environment-specific API subdomains (api-dev, api-staging)
resource "cloudflare_record" "api_environment_subdomain" {
  count   = var.create_dns_records && var.environment != "prod" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "api-${var.environment}"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied
}

# SSL/TLS Configuration - DISABLED for free plan compatibility
# resource "cloudflare_zone_settings_override" "ssl_settings" {
#   count   = var.configure_ssl ? 1 : 0
#   zone_id = var.cloudflare_zone_id
#   
#   settings {
#     ssl                      = var.ssl_mode
#     always_use_https        = "on"
#     min_tls_version         = "1.2"
#     tls_1_3                 = "on"
#     
#     minify {
#       css  = "on"
#       js   = "on"  
#       html = "on"
#     }
#     
#     security_level = var.security_level
#     browser_check  = "on"
#   }
# }

# Page Rules for optimization
resource "cloudflare_page_rule" "cache_static_assets" {
  count    = var.create_page_rules ? 1 : 0
  zone_id  = var.cloudflare_zone_id
  target   = "${var.domain_name}/static/*"
  priority = 1
  
  actions {
    cache_level         = "cache_everything"
    edge_cache_ttl      = 86400  # 24 hours
    browser_cache_ttl   = 86400
  }
}

resource "cloudflare_page_rule" "api_no_cache" {
  count    = var.create_page_rules ? 1 : 0
  zone_id  = var.cloudflare_zone_id
  target   = "api.${var.domain_name}/*"
  priority = 2
  
  actions {
    cache_level = "bypass"
  }
}

resource "cloudflare_page_rule" "www_redirect" {
  count    = var.create_page_rules ? 1 : 0
  zone_id  = var.cloudflare_zone_id
  target   = "www.${var.domain_name}/*"
  priority = 3
  
  actions {
    forwarding_url {
      url         = "https://${var.domain_name}/$1"
      status_code = 301
    }
  }
}