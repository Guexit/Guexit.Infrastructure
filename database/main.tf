data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "guexit-${var.env_name}"
  location = "France Central"
}

resource "random_password" "postgresql-pass" {
  length = 20
}

resource "azurerm_key_vault" "kv" {
  name                       = "guexit-${var.env_name}-keyvault"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update"
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge"
    ]
  }
}

resource "azurerm_key_vault_secret" "keyvault_postgresql" {
  name         = "postgresql-password"
  value        = random_password.postgresql-pass.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_postgresql_flexible_server" "postgresql-db" {
  name                   = "guexit-${var.env_name}-postgresql-server"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = var.postgresql_version
  delegated_subnet_id    = azurerm_subnet.default.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  sku_name               = "B_Standard_B1ms"

  administrator_login    = "postgres"
  administrator_password = azurerm_key_vault_secret.keyvault_postgresql.value
  
  storage_mb             = var.postgresql_storage_mb
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = "guexit-${var.env_name}-identityprovider-db"
  server_id = azurerm_postgresql_flexible_server.postgresql-db.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = "guexit-${var.env_name}-game-db"
  server_id = azurerm_postgresql_flexible_server.postgresql-db.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_virtual_network" "default" {
  name                = "guexit-${var.env_name}-virtual-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "default" {
  name                = "guexit-${var.env_name}-network-security-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow_postgresql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432" // PostgreSQL port
    source_address_prefix      = "VirtualNetwork" // Or specific IP ranges
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "default" {
  name                 = "guexit-${var.env_name}-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.rg.name
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

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_private_dns_zone" "default" {
  name                = "${var.env_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_subnet_network_security_group_association.default]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "guexit-${var.env_name}-private-dns-zone-virtual-network-link"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_servicebus_namespace" "default" {
  name                = "guexit-${var.env_name}-servicebus-namespace"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}