resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = "${var.env_name}-db"
  server_id = azurerm_postgresql_flexible_server.postgresql-db.id
  collation = "en_US.UTF8"
  charset   = "UTF8"
}