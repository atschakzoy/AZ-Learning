variable "environment" {
  type        = string
  default     = "dev"
  description = "name of the environment (dev, stage, prod)"
}

variable "suffix" {
  type        = string
  description = "short unique suffix for globally unique resource names"
}

variable "location" {
  type        = string
  default     = "East US"
  description = "Azure region for all resources"
}

variable "resource_group_name" {
  type        = string
  description = "name of the rg "
}

variable "storage_account_name" {
  type        = string
  description = "name of the storage account"
}

variable "container_name" {
  type        = string
  description = "name of the container/blob"
}
variable "key_vault_name" {
  type        = string
  description = "name of the keyvault"
}
variable "rbac_authorization_enabled" {
  type        = bool
  description = "activating or deactivationg the rbac authorization for keavault use"

}
variable "keyvault_sku_name" {
  type        = string
  description = "sku name for keyvault beetween premium and standerd"
}
variable "log_analytics_workspace_name" {
  type        = string
  description = "name of the log analytics workspace"
}

variable "openai_name" {
  type = string
  description = "name of the AZure OpenAI resource"
}

variable "openai_deployment_name" {
  type = string
  description = "name of the model deployment"
}