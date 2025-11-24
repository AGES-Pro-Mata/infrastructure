# Variables for Azure Blob Storage Frontend Module

variable "storage_account_name" {
  description = "Nome da Storage Account (3-24 caracteres alfanuméricos lowercase)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "O nome deve ter 3-24 caracteres alfanuméricos lowercase."
  }
}

variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
}

variable "location" {
  description = "Localização do Azure (ex: brazilsouth)"
  type        = string
  default     = "brazilsouth"
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

variable "replication_type" {
  description = "Tipo de replicação (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "enable_versioning" {
  description = "Habilitar versionamento de blobs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais para recursos"
  type        = map(string)
  default     = {}
}
