resource "azurerm_resource_group" "main" {
  name     = "rg-tfexample-${var.environment}-${var.suffix}"
  location = var.location
  tags = {
    managed-by = "terraform"
    stage      = "8"
  }
}
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "main" {
  name               = var.container_name
  storage_account_id = azurerm_storage_account.main.id
}

resource "azurerm_key_vault" "main" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  rbac_authorization_enabled = var.rbac_authorization_enabled
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.keyvault_sku_name
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}