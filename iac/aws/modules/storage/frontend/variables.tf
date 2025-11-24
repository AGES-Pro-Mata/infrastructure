# Variables for AWS S3 Frontend Module

variable "bucket_name" {
  description = "Nome do bucket S3 para frontend"
  type        = string
}

variable "domain_name" {
  description = "Nome do domínio (ex: promata.com.br)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "enable_versioning" {
  description = "Habilitar versionamento do bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais para recursos"
  type        = map(string)
  default     = {}
}
