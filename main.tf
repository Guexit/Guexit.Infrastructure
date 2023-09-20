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

resource "azurerm_key_vault_secret" "db-connection-string" {
  name         = "ConnectionStrings--Guexit-Game-GameDb"
  value        = "User ID=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_login};Password=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_password};Host=${azurerm_postgresql_flexible_server.postgresql-db-server.fqdn};Database=${azurerm_postgresql_flexible_server_database.game.name};"
  key_vault_id = azurerm_key_vault.kv.id
  
  depends_on = [azurerm_postgresql_flexible_server.postgresql-db-server, azurerm_postgresql_flexible_server_database.game]
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
  administrator_password = random_password.postgresql-pass.result
  storage_mb             = 32768
  zone                   = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

resource "azurerm_postgresql_flexible_server_database" "identityprovider" {
  name      = "guexit_identityprovider"
  server_id = azurerm_postgresql_flexible_server.postgresql-db-server.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "game" {
  name      = "guexit_game"
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

resource "azurerm_servicebus_namespace_authorization_rule" "default" {
  namespace_id        = azurerm_servicebus_namespace.default.id
  name                = "AllowListenSendAndManage"

  listen = true
  send   = true
  manage = true
}

resource "azurerm_key_vault_secret" "servicebus-connection-string" {
  name         = "ConnectionStrings--Guexit-ServiceBus"
  value        = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_servicebus_namespace_authorization_rule.default]
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

 resource "azurerm_container_app" "game" {
   name                         = "guexit-${var.env_name}-game"
   container_app_environment_id = azurerm_container_app_environment.default.id
   resource_group_name          = azurerm_resource_group.default.name
   revision_mode                = "Single"

   registry {
     server = "ghcr.io"
     username = "pablocom"
     password_secret_name = "pat"
   }

   template {
     min_replicas = 1
     max_replicas = 1
     
     container {
       name   = "guexit-game"
       image  = "ghcr.io/guexit/guexit-game:latest"
       cpu    = 0.25
       memory = "0.5Gi"
       
       env { 
         name = "ConnectionStrings__Guexit_Game_GameDb" 
         secret_name = "db-connection-string" 
       }
       env { 
         name = "ConnectionStrings__Guexit_ServiceBus" 
         secret_name = "service-bus-connection-string" 
       }
       env {
         name = "Database__MigrateOnStartup"
         value = "true"
       }
     }
   }
   
   secret { 
     name = "pat" 
     value = "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" 
   }
   secret { 
     name  = "db-connection-string" 
     value = azurerm_key_vault_secret.db-connection-string.value 
   }
   secret { 
     name  = "service-bus-connection-string"
     value = azurerm_key_vault_secret.servicebus-connection-string.value 
   }
 }
