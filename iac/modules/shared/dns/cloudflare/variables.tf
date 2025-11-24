# Variables for Cloudflare DNS Module

variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "domain_name" {
  description = "Nome do domínio (ex: promata.com.br)"
  type        = string
}

variable "frontend_endpoint" {
  description = "Endpoint do frontend (S3 website endpoint ou Azure Blob endpoint)"
  type        = string
  default     = ""
}

variable "backend_ip" {
  description = "IP público do servidor backend (EC2 ou Azure VM)"
  type        = string
  default     = ""
}

variable "create_traefik_record" {
  description = "Criar registro DNS para Traefik dashboard"
  type        = bool
  default     = false
}

variable "ssl_mode" {
  description = "Modo SSL do Cloudflare (off, flexible, full, strict)"
  type        = string
  default     = "flexible"

  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "ssl_mode deve ser: off, flexible, full ou strict"
  }
}
