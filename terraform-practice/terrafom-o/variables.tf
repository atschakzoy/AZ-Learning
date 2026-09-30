variable "suffix" {
  type        = string
  description = "Short unique suffix for globally unique names"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "eastus"
}