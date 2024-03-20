variable "env_name" {
  description = "The environment name."
  type = string
  default = "prod"

  validation {
    condition = length(var.env_name) > 0 && length(var.env_name) <= 15
    error_message = "Environment name length must be more than 0 and less or equal than 15"
  }
}

variable "azure_subscription_id" {
  description = "Azure subscription id."
  type = string
}
variable "azure_subscription_tenant_id"{
  description = "Azure subscription tenant id."
  type = string
}
variable "azure_client_id"{
  description = "Azure subscription client id."
  type = string
}
variable "azure_subscription_client_secret"{
  description = "Azure subscription client secret."
  type = string
}

variable "github_pat{
  description = "Github PAT to access to Github Registry."
  type = string
}

variable "az_flexible_server_sku"{
  description = "The SKU Name for the PostgreSQL Flexible Server. The name of the SKU, follows the tier + name pattern."
  type = string
  default = "B_Standard_B1ms"
}

variable "az_flexible_server_pg_version"{
  description = "PostgreSQL Flexible Server version."
  type = number
  default = 15
}
