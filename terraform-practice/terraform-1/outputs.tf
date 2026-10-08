output "openai_endpoint" {
  value = azurerm_cognitive_account.main.endpoint
}

output "app_service_url" {
  value = azurerm_linux_web_app.main.default_hostname
}


# --- Stage 9: Containers (commented out for Stage 6 App Service) ---
# output "acr_login_server" {
#   value = azurerm_container_registry.main.login_server
# }

# output "container_app_url" {
#   value = azurerm_container_app.main.ingress[0].fqdn
# }
