terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # ~> means "4.anything but not 5.0"
    }
  }
}

provider "azurerm" {
  features {} # required block, even if empty
}