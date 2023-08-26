resource "random_pet" "name_prefix" {
  prefix = var.name_prefix
  length = 1
}

data "azurerm_resource_group" "rg" {
  name     = "tryguessit-develop"
}

resource "random_password" "postgresql-pass" {
  length = 20
}

data "azurerm_key_vault" "default" {
  name                = "guexit-postgresql-key"
  resource_group_name = "tryguessit-develop"
}

resource "azurerm_key_vault_secret" "keyvault_postgresql" {
  name         = "postgresql-password"
  value        = random_password.postgresql-pass.result
  key_vault_id = data.azurerm_key_vault.default.id
}


resource "azurerm_postgresql_flexible_server" "postgresql-db" {
  name                   = "postgresql-${random_pet.name_prefix.id}-server"
  resource_group_name    = data.azurerm_resource_group.rg.name
  location               = data.azurerm_resource_group.rg.location
  version                = var.postgresql_version
  delegated_subnet_id    = azurerm_subnet.default.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  sku_name               = "GP_Standard_D2s_v3"

  administrator_login    = "postgres"
  administrator_password = azurerm_key_vault_secret.keyvault_postgresql.value

  zone                   = var.postgresql_zone
  storage_mb             = var.postgresql_storage_mb
  backup_retention_days  = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup
  
  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

resource "azurerm_virtual_network" "default" {
  name                = "${random_pet.name_prefix.id}-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "default" {
  name                = "${random_pet.name_prefix.id}-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

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
  name                 = "${random_pet.name_prefix.id}-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = data.azurerm_resource_group.rg.name
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
  name                = "${random_pet.name_prefix.id}-pdz.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name

  depends_on = [azurerm_subnet_network_security_group_association.default]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "${random_pet.name_prefix.id}-pdzvnetlink.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  resource_group_name   = data.azurerm_resource_group.rg.name
}