variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone:Read, DNS:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "domain_name" {
  description = "Domain name (e.g., promata.com.br)"
  type        = string
  default     = "promata.com.br"
}

variable "server_public_ip" {
  description = "Public IP address of the server"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "create_dns_records" {
  description = "Whether to create DNS records"
  type        = bool
  default     = true
}

variable "configure_ssl" {
  description = "Whether to configure SSL/TLS settings"
  type        = bool
  default     = true
}

variable "ssl_mode" {
  description = "SSL mode: off, flexible, full, strict"
  type        = string
  default     = "flexible"
  
  validation {
    condition = contains([
      "off", 
      "flexible", 
      "full", 
      "strict"
    ], var.ssl_mode)
    error_message = "SSL mode must be one of: off, flexible, full, strict."
  }
}

variable "security_level" {
  description = "Cloudflare security level: off, essentially_off, low, medium, high, under_attack"
  type        = string
  default     = "medium"
  
  validation {
    condition = contains([
      "off",
      "essentially_off", 
      "low", 
      "medium", 
      "high", 
      "under_attack"
    ], var.security_level)
    error_message = "Security level must be valid Cloudflare security level."
  }
}

variable "traefik_proxied" {
  description = "Whether to proxy Traefik dashboard through Cloudflare"
  type        = bool
  default     = false  # Usually DNS only for dashboard
}

variable "create_page_rules" {
  description = "Whether to create page rules for optimization"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = list(string)
  default     = []
}