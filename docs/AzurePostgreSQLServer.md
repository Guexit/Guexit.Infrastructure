# Azure PostgreSQL Server

## Overview

Azure Database for PostgreSQL is a fully managed database service that offers different deployment options catering to various needs for performance, customizability, and network isolation. The service offers built-in high availability, automated backups, scaling options, and enterprise-grade security features suitable for PostgreSQL databases.

## Types of Azure PostgreSQL Servers

### Single Server

- Simplified management: Most database management functions are automated.
- Automated backups: Automatic server backups with AES 256-bit encryption.
- Limited customization: Less control over configurations and settings.
- No start/stop capability: Server remains running all the time, which may affect the TCO.
- High Availability: Optimized for built-in high availability, supporting 99.99% availability on a single availability zone.

Terraform Configuration:

```terraform
resource "azurerm_postgresql_server" "example" {
  name                         = "example-postgresql-server"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.name
  sku_name                     = "GP_Gen5_2"
  storage_mb                   = 5120
  backup_retention_days        = 7
  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1CoR3!"
  version                      = "9.5"
  ssl_enforcement_enabled      = true
}
```

Key Parameters:

- `sku_name`: Specifies the SKU of the PostgreSQL Server.
- `storage_mb`: Specifies the amount of storage in megabytes.
- `backup_retention_days`: Number of days to keep backups.
- `ssl_enforcement_enabled`: Whether or not SSL is enforced for connections.

### Flexible Server

- Granular Control: More control over configurations and settings.
- Customizable Maintenance Windows: Define custom patching schedules.
- Start/Stop Capability: Option to stop the server to lower TCO.
- Network Isolation: Full private access to the server using Azure Virtual Network (VNet integration).

Terraform Configuration:

```terraform
resource "azurerm_postgresql_flexible_server" "example" {
  name                           = "example-flexibleserver"
  resource_group_name            = azurerm_resource_group.example.name
  location                       = azurerm_resource_group.example.location
  version                        = "12"
  sku_name                       = "GP_Standard_D4s_v3"
  storage_mb                     = 5120
  administrator_login            = "psqladminflex"
  administrator_password         = "H@Sh1CoR3Flex!"
  delegated_subnet_id            = azurerm_subnet.example.id
  high_availability              = "ZoneRedundant"
  public_network_access_enabled  = false
}
```

Key Parameters:

- `version`: PostgreSQL engine version.
- `sku_name`: Specifies the SKU, allowing more granular control over resources.
- `delegated_subnet_id`: Provides a higher degree of network isolation.
- `high_availability`: Option to make the server zone-redundant.
- `public_network_access_enabled`: Controls whether the server is accessible over the public internet.

## Comparison

|            Feature            |     Single Server     |     Flexible Server     |                      Notes                     |
|:-----------------------------:|:---------------------:|:-----------------------:|:----------------------------------------------:|
| Customizable Maintenance      | No                    | Yes                     |                                                |
| Start/Stop Capability         | No                    | Yes                     |                                                |
| Custom Configuration Options  | Limited               | Extensive               |                                                |
| Network Isolation Options     | Limited               | Extensive               | Flexible Server offers VNet Integration        |
| High Availability Options     | Limited               | Zone-redundant          |                                                |
| Pricing Models                | Fixed                 | Variable                | Flexible Server offers Burstable instances     |
| Resource Scaling              | Limited               | Granular                |                                                |
| PostgreSQL Versions Supported | Limited Range         | Wider Range             |                                                |
| Security Features             | Standard              | More Customizable       | Flexible Server offers Azure AD Authentication |
| Geo-Replication               | Not Available         | Available               | New in Flexible Server                         |
| Automated Backups             | Limited Customization | Extensive Customization | New in Flexible Server                         |
| Data Migration Options        | Limited               | More Options            | New in Flexible Server                         |
