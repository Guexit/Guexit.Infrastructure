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
  sku_name               = "B_Standard_B1ms"
  administrator_login    = "postgres"
  administrator_password = random_password.postgresql-pass.result
  storage_mb             = 32768
  zone                   = "1"
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
  container_access_type = "blob"
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

   ingress {
     target_port = 8080
     traffic_weight {
       percentage = 100
       latest_revision = true
     }
   }

   template {
     min_replicas = 1
     max_replicas = 1
     
     container {
       name   = "guexit-game"
       image  = "ghcr.io/guexit/guexit-game:1.3.5"
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

resource "azurerm_container_app" "identity-provider" {
   name                         = "guexit-${var.env_name}-identity-provider"
   container_app_environment_id = azurerm_container_app_environment.default.id
   resource_group_name          = azurerm_resource_group.default.name
   revision_mode                = "Single"
  
  ingress {
    target_port = 8080
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
         name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED"
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
         value = "auth-facebook-client-secret"
       }
       
       env {
         name = "IdentityServer__Clients__0__ClientSecrets__0__Value"
         secret_name = "guexit-client-secret" 
       }
       # TODO: When cyclic dependency is removed use guexit.com URLs
       env {
         name = "IdentityServer__Clients__0__RedirectUris__0"
         value = "empty"
       } 
       env {
         name = "IdentityServer__Clients__0__AllowedCorsOrigins__0"
         value = "empty"
       }
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
     value = "empty"
   }
   secret {
     name  = "auth-google-client-secret"
     value = "empty"
   }
   secret {
     name  = "auth-facebook-client-id"
     value = "empty"
   }
   secret {
     name  = "auth-facebook-client-secret"
     value = "empty"
   }
   secret {
     name = "guexit-client-secret"
     value = "empty"
   }
}

resource "azurerm_container_app" "frontend" {
  name                         = "guexit-${var.env_name}-frontend"
  container_app_environment_id = azurerm_container_app_environment.default.id
  resource_group_name          = azurerm_resource_group.default.name
  revision_mode                = "Single"
  
  ingress {
     target_port = 8080
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
      env {
        name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED"
        value = "true"
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
    value = "empty"
  }
}
