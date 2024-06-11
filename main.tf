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
  version                = var.az_flexible_server_pg_version
  sku_name               = var.az_flexible_server_sku
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

# Define the Storage Account Resource
resource "azurerm_storage_account" "blob_storage" {
  name                     = "guexit${var.env_name}imagesstorage"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  blob_properties {
    cors_rule {
        allowed_headers    = ["*"]
        allowed_methods    = ["GET","HEAD"]
        allowed_origins    = [
          "https://localhost:7200",
          "https://localhost:44458",
          "https://guexit.com"
        ]
        exposed_headers    = ["*"]
        max_age_in_seconds = 3600
      }
  }
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

  identity {
    identity_ids = []
    type = "SystemAssigned"
  }

  template {
    min_replicas = 1
    max_replicas = 1
    
    container {
      name   = "guexit-game"
      image  = "ghcr.io/guexit/guexit-game:1.3.5"
      cpu    = var.az_container_app_guexit_game_cpu
      memory = var.az_container_app_guexit_game_memory
      
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
      env {
        name = "ConnectionStrings__ApplicationInsights"
        value = "InstrumentationKey=832c4a22-1df0-412c-a26d-519a615c8d4f;IngestionEndpoint=https://francecentral-1.in.applicationinsights.azure.com/;LiveEndpoint=https://francecentral.livediagnostics.monitor.azure.com/"
      }
    }
  }
  
  secret { 
    name = "pat" 
    value = var.github_pat
  }
  secret { 
    name  = "db-connection-string" 
    value = "User ID=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_login};Password=${azurerm_postgresql_flexible_server.postgresql-db-server.administrator_password};Host=${azurerm_postgresql_flexible_server.postgresql-db-server.fqdn};Database=${azurerm_postgresql_flexible_server_database.game.name};"
  }
  secret { 
    name  = "service-bus-connection-string"
    value = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
  }
  secret {
    name = "appinsights-connection-string"
    value = azurerm_application_insights.game-insights.connection_string
  }
  secret {
    name = "appinsights-connection-string"
    value = azurerm_application_insights.game-insights.connection_string
  }
  lifecycle {
    ignore_changes = [
      secret,
      ingress, # We cannnot add the custom 
      template[0].container[0].image, # Ignore image tag changes. 

    ]
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
      cpu    = var.az_container_app_guexit_identity_provider_cpu
      memory = var.az_container_app_guexit_identity_provider_memory
      env {
        name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED"
        value = "true"
      }
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
        name = "Authentication__Discord__ClientId"
        secret_name = "auth-discord-client-id"
      }
      env {
        name = "Authentication__Discord__ClientSecret"
        secret_name = "auth-discord-client-secret"
      }

      env {
        name = "Authentication__Twitch__ClientId"
        secret_name = "auth-twitch-client-id"
      }
      env {
        name = "Authentication__Twitch__ClientSecret"
        secret_name = "auth-twitch-client-secret"
      }
      env {
        name = "IdentityServer__Clients__0__ClientSecrets__0__Value"
        value = "K7gNU3sdo+OL0wNhqoVWhr3g6s1xYv72ol/pe/Unols=" 
      }
      # TODO: When cyclic dependency is removed use guexit.com URLs
      env {
        name = "IdentityServer__Clients__0__RedirectUris__0"
        value = "https://guexit.com/signin-oidc"
      } 
      env {
      name = "IdentityServer__Clients__0__PostLogoutRedirectUris__0"
      value = "https://guexit.com/signout-callback-oidc"
      }
      env {
        name = "ConnectionStrings__ApplicationInsights"
        value = "InstrumentationKey=832c4a22-1df0-412c-a26d-519a615c8d4f;IngestionEndpoint=https://francecentral-1.in.applicationinsights.azure.com/;LiveEndpoint=https://francecentral.livediagnostics.monitor.azure.com/"
      }
    }
  }
  
  secret { 
    name = "pat" 
    value = var.github_pat
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
    name  = "auth-discord-client-id"
    value = "empty"
  }
  secret {
    name  = "auth-discord-client-secret"
    value = "empty"
  }
  secret {
    name  = "auth-twitch-client-id"
    value = "empty"
  }
  secret {
    name  = "auth-twitch-client-secret"
    value = "empty"
  }
  secret {
    name = "guexit-client-secret"
    value = "empty"
  }
  secret {
    name = "appinsights-connection-string"
    value = azurerm_application_insights.game-insights.connection_string
  }
  # Lifecycle block to ignore secret changes
  lifecycle {
    ignore_changes = [
      secret,
      ingress,
      template[0].container[0].image, # Ignore image tag changes. 
    ]
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
      cpu    = var.az_container_app_guexit_frontend_cpu
      memory = var.az_container_app_guexit_frontend_memory
      env {
        name = "ASPNETCORE_FORWARDEDHEADERS_ENABLED"
        value = "true"
      }
      env {
        name = "ConnectionStrings__Guexit_ServiceBus"
        secret_name = "service-bus-connection-string"
      }
      env {
        name = "Authorization__AuthorityUrl"
        value = "https://identity.guexit.com"
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
      env {
        name = "ConnectionStrings__ApplicationInsights"
        value = "InstrumentationKey=832c4a22-1df0-412c-a26d-519a615c8d4f;IngestionEndpoint=https://francecentral-1.in.applicationinsights.azure.com/;LiveEndpoint=https://francecentral.livediagnostics.monitor.azure.com/"
      }
    }
  }

  secret {
    name = "pat"
    value = var.github_pat
  }
  secret {
    name  = "service-bus-connection-string"
    value = azurerm_servicebus_namespace_authorization_rule.default.primary_connection_string
  }
  secret {
    name = "guexit-client-secret"
    value = "secret"
  }
  secret {
    name = "appinsights-connection-string"
    value = azurerm_application_insights.game-insights.connection_string
  }
  lifecycle {
    ignore_changes = [
      secret,
      ingress,
      template[0].container[0].image,
    ]
  }
}

resource "azurerm_application_insights" "game-insights" {
  name                = "guexit-${var.env_name}-appinsights"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  workspace_id        = azurerm_log_analytics_workspace.default.id
  application_type    = "web"
  sampling_percentage = var.az_application_insights_sampling_rate
}
