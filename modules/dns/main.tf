# ============================================================================
# modules/dns/main.tf
# ============================================================================
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Define all services that will be exposed
  services = {
    # Main application
    "@" = {
      description = "Main application frontend"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
    "www" = {
      description = "WWW redirect"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
    
    # API Backend
    "api" = {
      description = "Backend API service"
      ip_address  = var.worker_public_ip
      proxied     = true
    }
    
    # Management Services
    "traefik" = {
      description = "Traefik reverse proxy dashboard"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
    "grafana" = {
      description = "Grafana monitoring dashboard"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
    "prometheus" = {
      description = "Prometheus monitoring"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
    
    # Analytics and BI
    "analytics" = {
      description = "Umami analytics dashboard"
      ip_address  = var.worker_public_ip
      proxied     = true
    }
    "metabase" = {
      description = "Metabase BI dashboard"
      ip_address  = var.worker_public_ip
      proxied     = true
    }
    
    # Database Management
    "prisma" = {
      description = "Prisma Studio - Database management"
      ip_address  = var.manager_public_ip
      proxied     = true
    }
  }
  
  # Environment-specific subdomain (for non-prod)
  env_subdomain = var.environment != "prod" ? "${var.environment}.${var.domain_name}" : null
}

# ============================================================================
# CLOUDFLARE DNS RECORDS - MAIN SERVICES
# ============================================================================
resource "cloudflare_record" "services" {
  for_each = local.services
  
  zone_id = var.cloudflare_zone_id
  name    = each.key
  content  = each.value.ip_address
  type    = "A"
  ttl     = 1
  proxied = each.value.proxied
  comment = "${each.value.description} - ${var.environment} environment"

  tags = [
    var.environment,
    "terraform",
    var.project_name
  ]
}

# ============================================================================
# ENVIRONMENT-SPECIFIC SUBDOMAIN (for dev/staging)
# ============================================================================
resource "cloudflare_record" "environment_main" {
  count = var.environment != "prod" ? 1 : 0
  
  zone_id = var.cloudflare_zone_id
  name    = var.environment
  content  = var.manager_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Environment-specific subdomain for ${var.environment}"

  tags = [
    var.environment,
    "terraform",
    var.project_name
  ]
}

# ============================================================================
# SES DNS RECORDS (if SES is enabled)
# ============================================================================
# These would be created by the SES module, but we can reference them here
# for documentation purposes

# ============================================================================
# MX RECORD FOR EMAIL (if needed)
# ============================================================================
resource "cloudflare_record" "mx" {
  count = var.environment == "prod" ? 1 : 0
  
  zone_id  = var.cloudflare_zone_id
  name     = "@"
  content  = "10 inbound-smtp.us-east-2.amazonaws.com"
  type     = "MX"
  ttl      = 3600
  comment  = "MX record for SES email receiving"

  tags = [
    var.environment,
    "terraform",
    var.project_name,
    "email"
  ]
}

# ============================================================================
# TXT RECORD FOR SPF
# ============================================================================
resource "cloudflare_record" "spf" {
  count = var.environment == "prod" ? 1 : 0
  
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content  = "v=spf1 include:amazonses.com ~all"
  type    = "TXT"
  ttl     = 3600
  comment = "SPF record for SES"

  tags = [
    var.environment,
    "terraform",
    var.project_name,
    "email"
  ]
}
