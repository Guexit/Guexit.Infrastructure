output "resource_group_name" {
  value = data.azurerm_resource_group.rg.name
}

output "azurerm_postgresql_flexible_server" {
  value = azurerm_postgresql_flexible_server.postgresql-db.name
}

output "postgresql_flexible_server_database_name" {
  value = azurerm_postgresql_flexible_server_database.default.name
}

output "postgresql_flexible_server_admin_password" {
  sensitive = true
  value     = azurerm_postgresql_flexible_server.postgresql-db.administrator_password
}