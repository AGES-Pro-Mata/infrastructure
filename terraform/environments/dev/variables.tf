# Variables for Pro-Mata Development Environment

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-promata-dev"
}

variable "azure_location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US 2"
}

variable "vm_size" {
  description = "Size of the virtual machines"
  type        = string
  default     = "Standard_B2s"
  
  validation {
    condition = contains([
      "Standard_B1s", "Standard_B1ms", "Standard_B2s", 
      "Standard_B2ms", "Standard_B4ms", "Standard_D2s_v3"
    ], var.vm_size)
    error_message = "VM size must be a valid Azure size for students."
  }
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "promata"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "pro-mata"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "pro-mata"
    ManagedBy   = "terraform"
    CostCenter  = "ages-pucrs"
  }
}