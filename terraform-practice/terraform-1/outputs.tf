output "openai_endpoint" {
    value = azurerm_cognitive_account.main.endpoint
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "container_app_url" {
  value = azurerm_container_app.main.ingress[0].fqdn
}
