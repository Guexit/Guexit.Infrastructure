data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "default" {
  name     = "guexit-${var.env_name}"
  location = "France Central"
}

resource "random_password" "postgresql-pass" {
  length = 20
  override_special = "_-+.'"
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

resource "azurerm_postgresql_flexible_server_database" "identity-provider" {
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
     value = "User ID=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_login};Password=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_password};Host=${azurerm_postgresql_flexible_server.postgresql-db-server.fqdn};Database=${azurerm_postgresql_flexible_server_database.game.name};"
   }
   secret { 
     name  = "service-bus-connection-string"
     value = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
   }
 }

resource "azurerm_storage_account" "blob_storage" {
  name                     = "guexit${var.env_name}imagesstorage"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "card_images" {
  name                  = "card-images"
  storage_account_name  = azurerm_storage_account.blob_storage.name
  container_access_type = "private"
}

resource "azurerm_container_app" "identity-provider" {
   name                         = "guexit-${var.env_name}-identity-provider"
   container_app_environment_id = azurerm_container_app_environment.default.id
   resource_group_name          = azurerm_resource_group.default.name
   revision_mode                = "Single"
  
  ingress {
    target_port = 80
    external_enabled = true
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
  
   registry {
     server = "ghcr.io"
     username = "pablocom"
     password_secret_name = "pat"
   }

   template {
     min_replicas = 1
     max_replicas = 1
     
     container {
       name   = "guexit-identity-provider"
       image  = "ghcr.io/guexit/guexit-identity-provider:latest"
       cpu    = 0.25
       memory = "0.5Gi"
       
       env { 
         name = "ConnectionStrings__Guexit_IdentityProvider_IdentityUsers" 
         secret_name = "db-connection-string" 
       }
       env { 
         name = "ConnectionStrings__Guexit_IdentityProvider_IdentityServerOperationalData" 
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

       env {
         name = "Authentication__Google__ClientId"
         secret_name = "auth-google-client-id"
       }
       env {
         name = "Authentication__Google__ClientSecret"
         secret_name = "auth-google-client-secret"
       }
       env {
         name = "Authentication__Facebook__ClientId"
         secret_name = "auth-facebook-client-id"
       }
       env {
         name = "Authentication__Facebook__ClientSecret"
         value = "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"
       }
       
       env {
         name = "IdentityServer__Clients__0__ClientSecrets__0__Value"
         secret_name = "guexit-client-secret" 
       }
#       env {
#         name = "IdentityServer__Clients__0__RedirectUris__0"
#         value = "${azurerm_container_app.frontend.ingress}/signin-oidc"
#       }
#       env {
#         name = "IdentityServer__Clients__0__AllowedCorsOrigins__0"
#         value = azurerm_container_app.frontend.ingress
#       }
     }
   }
   
   secret { 
     name = "pat" 
     value = "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" 
   }
   secret { 
     name  = "db-connection-string" 
     value = "User ID=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_login};Password=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_password};Host=${azurerm_postgresql_flexible_server.postgresql-db-server.fqdn};Database=${azurerm_postgresql_flexible_server_database.identity-provider.name};"
   }
   secret { 
     name  = "service-bus-connection-string"
     value = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
   }
   secret {
     name  = "auth-google-client-id"
     value = "231047044910-456svfn90ou310ib43j268ctoif38nrf.apps.googleusercontent.com"
   }
   secret {
     name  = "auth-google-client-secret"
     value = "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"
   }
   secret {
     name  = "auth-facebook-client-id"
     value = "649484549980563"
   }
   secret {
     name  = "auth-facebook-client-secret"
     value = "de219a23a0688faa5ff03b7afd542193"
   }
   secret {
     name = "guexit-client-secret"
     value = "K7gNU3sdo+OL0wNhqohWhr3gas0xYv72ol/pe/Unols="
   }
}

resource "azurerm_container_app" "frontend" {
  name                         = "guexit-${var.env_name}-frontend"
  container_app_environment_id = azurerm_container_app_environment.default.id
  resource_group_name          = azurerm_resource_group.default.name
  revision_mode                = "Single"
  
  ingress {
     target_port = 80
     external_enabled = true
     traffic_weight {
       percentage = 100
       latest_revision = true
     }
   }

  registry {
    server = "ghcr.io"
    username = "pablocom"
    password_secret_name = "pat"
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "guexit-frontend"
      image  = "ghcr.io/guexit/guexit-frontend:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "ConnectionStrings__Guexit_ServiceBus"
        secret_name = "service-bus-connection-string"
      }
      env {
        name = "Authorization__AuthorityUrl"
        value = "https://${azurerm_container_app.identity-provider.name}"
      }
      env {
        name = "Authorization__ClientId"
        value = "guexit-bff"
      }
      env {
        name = "Authorization__ClientSecret"
        secret_name = "guexit-client-secret"
      }
      // noinspection HttpUrlsUsage, secured internal cluster traffic
      env {
        name = "ReverseProxy__Clusters__game__Destinations__destination__Address"
        value = "http://${azurerm_container_app.game.name}"
      }
    }
  }

  secret {
    name = "pat"
    value = "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"
  }
  secret {
    name  = "service-bus-connection-string"
    value = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
  }
  secret {
    name = "guexit-client-secret"
    value = "K7gNU3sdo+OL0wNhqohWhr3gas0xYv72ol/pe/Unols="
  }
}