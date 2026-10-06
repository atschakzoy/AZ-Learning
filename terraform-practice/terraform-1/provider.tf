terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatern001"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

}

data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}
