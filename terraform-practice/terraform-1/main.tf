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

resource "azurerm_cognitive_account" "main" {
  name                = var.openai_name
  location            = "swedencentral"
  resource_group_name = azurerm_resource_group.main.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "main" {
  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.main.id

  model {
    format  = "OpenAI"
    name    = "gpt-4.1-mini"
    version = "2025-04-14"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }

}

resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "main" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      python_version = "3.12"
    }
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 main:app"
  }

  app_settings = {
    AZURE_OPENAI_ENDPOINT          = azurerm_cognitive_account.main.endpoint
    AZURE_OPENAI_DEPLOYMENT        = var.openai_deployment_name
    KEY_VAULT_URL                  = azurerm_key_vault.main.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
}

resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_openai_user" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      python_version = "3.12"
    }
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 main:app"
  }

  app_settings = {
    AZURE_OPENAI_ENDPOINT          = azurerm_cognitive_account.main.endpoint
    AZURE_OPENAI_DEPLOYMENT        = var.openai_deployment_name
    KEY_VAULT_URL                  = azurerm_key_vault.main.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
}
resource "azurerm_role_assignment" "staging_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app_slot.staging.identity[0].principal_id
}

resource "azurerm_role_assignment" "staging_openai_user" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_web_app_slot.staging.identity[0].principal_id
}



# --- Stage 9: Containers (commented out for Stage 6 App Service) ---
# resource "azurerm_container_registry" "main" {
#   name = var.acr_name
#   resource_group_name = azurerm_resource_group.main.name
#   location = azurerm_resource_group.main.location
#   sku = "Basic"
#   admin_enabled = true
# }

# resource "azurerm_user_assigned_identity" "main" {
#   name                = var.managed_identity_name
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
# }

# resource "azurerm_role_assignment" "kv_secrets_user" {
#   scope                = azurerm_key_vault.main.id
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = azurerm_user_assigned_identity.main.principal_id
# }

# resource "azurerm_container_app_environment" "main" {
#   name                       = var.container_app_env_name
#   resource_group_name        = azurerm_resource_group.main.name
#   location                   = azurerm_resource_group.main.location
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
# }

# resource "azurerm_container_app" "main" {
#   name                         = var.container_app_name
#   resource_group_name          = azurerm_resource_group.main.name
#   container_app_environment_id = azurerm_container_app_environment.main.id
#   revision_mode                = "Single"
#
#   identity {
#     type         = "UserAssigned"
#     identity_ids = [azurerm_user_assigned_identity.main.id]
#   }
#
#   template {
#     container {
#       name   = "ai-app"
#       image  = "${azurerm_container_registry.main.login_server}/ai-app:latest"
#       cpu    = 0.25
#       memory = "0.5Gi"
#
#       env {
#         name  = "AZURE_OPENAI_ENDPOINT"
#         value = azurerm_cognitive_account.main.endpoint
#       }
#       env {
#         name  = "AZURE_OPENAI_DEPLOYMENT"
#         value = var.openai_deployment_name
#       }
#       env {
#         name  = "KEY_VAULT_URL"
#         value = azurerm_key_vault.main.vault_uri
#       }
#       env {
#         name  = "AZURE_CLIENT_ID"
#         value = azurerm_user_assigned_identity.main.client_id
#       }
#     }
#   }
#
#   ingress {
#     external_enabled = true
#     target_port      = 5000
#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }
#
#   registry {
#     server   = azurerm_container_registry.main.login_server
#     username = azurerm_container_registry.main.admin_username
#     password_secret_name = "acr-password"
#   }
#
#   secret {
#     name  = "acr-password"
#     value = azurerm_container_registry.main.admin_password
#   }
# }
