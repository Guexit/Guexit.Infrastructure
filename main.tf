data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "default" {
  name     = "guexit-${var.env_name}"
  location = "France Central"
}

resource "azurerm_key_vault" "kv" {
  name                = "guexit-${var.env_name}-keyvault"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "List",
      "Recover"
    ]
  }
}

resource "random_password" "postgresql-pass" {
  length = 20
}

resource "azurerm_key_vault_secret" "postgresql-password" {
  name         = "postgresql-password"
  value        = random_password.postgresql-pass.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_postgresql_flexible_server" "postgresql-db-server" {
  name                   = "guexit-${var.env_name}-postgresql-server"
  resource_group_name    = azurerm_resource_group.default.name
  location               = azurerm_resource_group.default.location
  version                = "15"
  delegated_subnet_id    = azurerm_subnet.postgresql.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  sku_name               = "B_Standard_B1ms"
  administrator_login    = "postgres"
  administrator_password = azurerm_key_vault_secret.postgresql-password.value
  storage_mb             = 32768
  zone                   = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

resource "azurerm_postgresql_flexible_server_database" "identityprovider-db" {
  name      = "guexit-${var.env_name}-identityprovider-db"
  server_id = azurerm_postgresql_flexible_server.postgresql-db-server.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "game-db" {
  name      = "guexit-${var.env_name}-game-db"
  server_id = azurerm_postgresql_flexible_server.postgresql-db-server.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_virtual_network" "default" {
  name                = "guexit-${var.env_name}-virtual-network"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "default" {
  name                = "guexit-${var.env_name}-network-security-group"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  security_rule {
    name                       = "allow_postgresql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "postgresql" {
  name                 = "guexit-${var.env_name}-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.default.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "container_app_environment" {
  name                 = "guexit-${var.env_name}-container-app-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.default.name
  address_prefixes     = ["10.0.4.0/23"]
}

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.postgresql.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_private_dns_zone" "default" {
  name                = "${var.env_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.default.name

  depends_on = [azurerm_subnet_network_security_group_association.default]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "guexit-${var.env_name}-private-dns-zone-virtual-network-link"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  resource_group_name   = azurerm_resource_group.default.name
}

resource "azurerm_servicebus_namespace" "default" {
  name                = "guexit-${var.env_name}-servicebus-namespace"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Standard"
}

resource "azurerm_log_analytics_workspace" "default" {
  name                = "guexit-${var.env_name}-log-analytics-workspace"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "default" {
  name                       = "guexit-${var.env_name}-container-apps"
  location                   = azurerm_resource_group.default.location
  resource_group_name        = azurerm_resource_group.default.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.default.id
  infrastructure_subnet_id   = azurerm_subnet.container_app_environment.id
}

# resource "azurerm_container_app" "game" {
#   name                         = "guexit-${var.env_name}-container-app-game"
#   container_app_environment_id = azurerm_container_app_environment.default.id
#   resource_group_name          = azurerm_resource_group.default.name
#   revision_mode                = "Single"

#   template {
#     container {
#       name   = "guexit-game"
#       image  = "TBD"
#       cpu    = 0.25
#       memory = "0.5Gi"
#     }
#   }
# }