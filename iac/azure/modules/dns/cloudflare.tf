terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Define all services exposed by the stack dynamically
locals {
  # Services exposed by our Docker stack with their configurations
  services = {
    # Main domain (frontend)
    # "@" = {
    #   description = "Main application frontend"
    #   service     = "frontend"
    #   port        = 3000
    #   proxied     = true  # Always proxied (orange cloud)
    # }
    # WWW redirect
    "www" = {
      description = "WWW redirect to main domain"
      service     = "frontend"
      port        = 3000
      proxied     = true # Always proxied (orange cloud)
    }
    # API Backend
    "api" = {
      description = "Backend API service"
      service     = "backend"
      port        = 3000
      proxied     = true # Always proxied (orange cloud)
    }
    # Traefik Dashboard
    "traefik" = {
      description = "Traefik reverse proxy dashboard"
      service     = "traefik"
      port        = 8080
      proxied     = true # Always proxied (orange cloud)
    }

    # Analytics
    "analytics" = {
      description = "Umami analytics dashboard"
      service     = "umami"
      port        = 3000
      proxied     = true # Always proxied (orange cloud)
    }
    "metabase" = {
      description = "Metabase analytics dashboard"
      service     = "metabase"
      port        = 3000
      proxied     = true # Always proxied (orange cloud)
    }
    # Database Management
    "pgadmin" = {
      description = "PostgreSQL administration"
      service     = "pgadmin"
      port        = 80
      proxied     = true # Always proxied (orange cloud)
    }
  }
}

# Create DNS records for all services dynamically
resource "cloudflare_record" "services" {
  for_each = var.create_dns_records ? local.services : {}

  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = each.value.proxied
  comment = "${each.value.description} - Port ${each.value.port} - Service: ${each.value.service}"

  tags = [
    var.environment,
    "terraform",
    "promata",
    each.value.service
  ]
}

# All DNS records are now handled dynamically by the "services" resource above

# Environment-specific subdomains
resource "cloudflare_record" "environment_subdomain" {
  count   = var.create_dns_records && var.environment != "prod" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.environment
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied

  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

# Environment-specific API subdomains
resource "cloudflare_record" "api_environment_subdomain" {
  count   = var.create_dns_records && var.environment != "prod" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "api-${var.environment}"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.dns_records_proxied

  tags = [
    var.environment,
    "terraform",
    "promata",
    "api"
  ]
}

# SSL/TLS Configuration
resource "cloudflare_zone_settings_override" "ssl_settings" {
  count   = var.configure_ssl ? 1 : 0
  zone_id = var.cloudflare_zone_id

  settings {
    ssl                      = var.ssl_mode
    always_use_https         = "on"
    min_tls_version          = "1.2"
    opportunistic_encryption = "on"
    tls_1_3                  = "zrt"
    brotli                   = "on"

    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }

    security_header {
      enabled = true
    }
  }
}

# Page Rules for optimization
resource "cloudflare_page_rule" "cache_static_assets" {
  count    = var.create_page_rules ? 1 : 0
  zone_id  = var.cloudflare_zone_id
  target   = "${var.domain_name}/static/*"
  priority = 1

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 86400 # 24 hours
    browser_cache_ttl = 86400
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
