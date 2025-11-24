# Cloudflare DNS Module - Shared (AWS + Azure)
# Manages DNS records and SSL for PRO-MATA

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.46"
    }
  }
}

# Root domain → Frontend (CNAME para S3/Blob)
resource "cloudflare_record" "root" {
  count = var.frontend_endpoint != "" ? 1 : 0

  zone_id = var.zone_id
  name    = var.domain_name
  content = var.frontend_endpoint
  type    = "CNAME"
  ttl     = 1 # Auto (proxied)
  proxied = true

  comment = "Frontend Static Website (S3/Blob Storage)"
}

# WWW → Root domain (redirect handled by Page Rule)
resource "cloudflare_record" "www" {
  count = var.frontend_endpoint != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "www"
  content = var.domain_name
  type    = "CNAME"
  ttl     = 1
  proxied = true

  comment = "WWW redirect to root domain"
}

# API → Backend Server (A record para EC2/VM)
resource "cloudflare_record" "api" {
  count = var.backend_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "api"
  content = var.backend_ip
  type    = "A"
  ttl     = 1
  proxied = true

  comment = "Backend API Server"
}

# Analytics (Umami) → Backend Server
resource "cloudflare_record" "analytics" {
  count = var.backend_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "analytics"
  content = var.backend_ip
  type    = "A"
  ttl     = 1
  proxied = true

  comment = "Umami Analytics Dashboard"
}

# Metabase (BI) → Backend Server
resource "cloudflare_record" "metabase" {
  count = var.backend_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "metabase"
  content = var.backend_ip
  type    = "A"
  ttl     = 1
  proxied = true

  comment = "Metabase BI Dashboard"
}

# Traefik Dashboard → Backend Server (opcional)
resource "cloudflare_record" "traefik" {
  count = var.backend_ip != "" && var.create_traefik_record ? 1 : 0

  zone_id = var.zone_id
  name    = "traefik"
  content = var.backend_ip
  type    = "A"
  ttl     = 1
  proxied = true

  comment = "Traefik Reverse Proxy Dashboard"
}

# SSL/TLS Settings
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.zone_id

  settings {
    # SSL
    ssl                      = var.ssl_mode
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
    tls_1_3                  = "zrt"

    # Security
    security_level           = "medium"
    opportunistic_encryption = "on"

    # Performance
    brotli        = "on"
    http3         = "on"
    early_hints   = "on"
    rocket_loader = "off" # Pode quebrar SPAs

    # Caching
    browser_cache_ttl = 14400 # 4 horas

    # Minification
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
  }
}

# Page Rule: WWW → Root Redirect
resource "cloudflare_page_rule" "www_redirect" {
  zone_id  = var.zone_id
  target   = "www.${var.domain_name}/*"
  priority = 1

  actions {
    forwarding_url {
      url         = "https://${var.domain_name}/$1"
      status_code = 301
    }
  }
}

# Page Rule: Frontend Cache (Static Assets)
resource "cloudflare_page_rule" "frontend_cache" {
  count = var.frontend_endpoint != "" ? 1 : 0

  zone_id  = var.zone_id
  target   = "${var.domain_name}/assets/*"
  priority = 2

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 31536000 # 1 ano
    browser_cache_ttl = 31536000
  }
}

# Page Rule: API No Cache
resource "cloudflare_page_rule" "api_no_cache" {
  count = var.backend_ip != "" ? 1 : 0

  zone_id  = var.zone_id
  target   = "api.${var.domain_name}/*"
  priority = 3

  actions {
    cache_level      = "bypass"
    disable_security = false
  }
}
