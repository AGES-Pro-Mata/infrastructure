# Variables for Azure Development Environment

variable "azure_region" {
  description = "Azure region for development environment"
  type        = string
  default     = "East US 2"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for virtual machines"
  type        = string
  default     = "promata"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "pro-mata"
}
