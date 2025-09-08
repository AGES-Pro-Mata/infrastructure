variable "resource_group_name" {
  description = "Nome do grupo de recursos para a aplicação."
  type        = string
}

variable "location" {
  description = "A região do Azure onde os recursos serão criados."
  type        = string
}

variable "app_name" {
  description = "O nome da sua aplicação. Usado para nomear recursos."
  type        = string
}