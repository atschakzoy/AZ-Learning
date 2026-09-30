resource "azurerm_resource_group" "main" {
  name     = "rg-platform-dev"
  location = "East US"
}

resource "azurerm_storage_account" "main" {
  name                     = "sttfpractice001"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}