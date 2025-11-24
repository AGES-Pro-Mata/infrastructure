# ============================================================================
# modules/dns/main.tf
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Define all services that will be exposed - single instance
  services = {
    # Main application frontend - served from EC2 instance
    "@" = {
      description = "Main application frontend (root domain)"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    "www" = {
      description = "WWW subdomain"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    # API Backend
    "api" = {
      description = "Backend API service"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    # Management Services
    "traefik" = {
      description = "Traefik reverse proxy dashboard"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    # Analytics and BI
    "analytics" = {
      description = "Umami analytics dashboard"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    "metabase" = {
      description = "Metabase BI dashboard"
      ip_address  = var.instance_public_ip
      proxied     = true
    }

    # Database Management
    "prisma" = {
      description = "Prisma Studio - Database management"
      ip_address  = var.instance_public_ip
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

  zone_id         = var.cloudflare_zone_id
  name            = each.key
  content         = each.value.ip_address
  type            = "A"
  ttl             = 1
  proxied         = each.value.proxied
  allow_overwrite = true
  comment         = "${each.value.description} - ${var.environment} environment"
}

# ============================================================================
# CLOUDFRONT DNS RECORDS (removed - no longer using CloudFront)
# ============================================================================
# CloudFront has been removed from the infrastructure.
# Root and www domains now point directly to EC2 instance via the services map above.

# ============================================================================
# ENVIRONMENT-SPECIFIC SUBDOMAIN (for dev/staging)
# ============================================================================
resource "cloudflare_record" "environment_main" {
  count = var.environment != "prod" ? 1 : 0

  zone_id         = var.cloudflare_zone_id
  name            = var.environment
  content         = var.instance_public_ip
  type            = "A"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
  comment         = "Environment-specific subdomain for ${var.environment}"
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
  priority = 10
  content  = "inbound-smtp.us-east-2.amazonaws.com"
  type     = "MX"
  ttl      = 3600
  comment  = "MX record for SES email receiving"
}

# ============================================================================
# TXT RECORD FOR SPF
# ============================================================================
resource "cloudflare_record" "spf" {
  count = var.environment == "prod" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "v=spf1 include:amazonses.com ~all"
  type    = "TXT"
  ttl     = 3600
  comment = "SPF record for SES"
}

# ============================================================================
# CLOUDFLARE PAGE RULE (removed - no longer needed)
# ============================================================================
# Frontend is now served directly from EC2 instance via Traefik.
# No S3 proxy or CloudFront redirection needed.
