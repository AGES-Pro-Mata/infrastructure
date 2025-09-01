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
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

resource "cloudflare_record" "www" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

resource "cloudflare_record" "api" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "api"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

resource "cloudflare_record" "traefik" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "traefik"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = var.traefik_proxied  # Usually false for dashboard
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

resource "cloudflare_record" "pgadmin" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "pgadmin"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

resource "cloudflare_record" "grafana" {
  count   = var.create_dns_records ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

# Environment-specific subdomains
resource "cloudflare_record" "environment_subdomain" {
  count   = var.create_dns_records && var.environment != "prod" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.environment
  content = var.server_public_ip
  type    = "A"
  ttl     = 1
  proxied = true
  
  tags = [
    var.environment,
    "terraform",
    "promata"
  ]
}

# SSL/TLS Configuration
resource "cloudflare_zone_settings_override" "ssl_settings" {
  count   = var.configure_ssl ? 1 : 0
  zone_id = var.cloudflare_zone_id
  
  settings {
    ssl                      = var.ssl_mode
    always_use_https        = "on"
    min_tls_version         = "1.2"
    opportunistic_encryption = "on"
    tls_1_3                 = "zrt"
    brotli                  = "on"
    
    minify {
      css  = "on"
      js   = "on"  
      html = "on"
    }
    
    security_level = var.security_level
    browser_check  = "on"
  }
}

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

variable "create_dns_records" {
  description = "Whether to create DNS records"
  type        = bool
  default     = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "server_public_ip" {
  description = "Public IP address of the server"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "traefik_proxied" {
  description = "Whether Traefik subdomain should be proxied through Cloudflare"
  type        = bool
  default     = false
}

variable "configure_ssl" {
  description = "Whether to configure SSL settings"
  type        = bool
  default     = true
}

variable "ssl_mode" {
  description = "SSL mode for Cloudflare"
  type        = string
  default     = "flexible"
  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "SSL mode must be one of: off, flexible, full, strict."
  }
}

variable "security_level" {
  description = "Security level for Cloudflare"
  type        = string
  default     = "medium"
  validation {
    condition     = contains(["essentially_off", "low", "medium", "high", "under_attack"], var.security_level)
    error_message = "Security level must be one of: essentially_off, low, medium, high, under_attack."
  }
}

variable "create_page_rules" {
  description = "Whether to create page rules"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
}