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

variable "github_pat"{
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

variable "az_container_app_guexit_game_cpu"{
  description = "The number of CPU cores to allocate to Guexit Game in Container Apps."
  type = number
  default = 0.25
}

variable "az_container_app_guexit_game_memory"{
  description = "The number of memory to allocate to Guexit Game in Container Apps."
  type = string
  default = "0.5Gi"
}

variable "az_container_app_guexit_identity_provider_cpu"{
  description = "The number of CPU cores to allocate to Guexit Game in Container Apps."
  type = number
  default = 0.25
}

variable "az_container_app_guexit_identity_provider_memory"{
  description = "The number of memory to allocate to Guexit Game in Container Apps."
  type = string
  default = "0.5Gi"
}

variable "az_container_app_guexit_frontend_cpu"{
  description = "The number of CPU cores to allocate to Guexit Game in Container Apps."
  type = number
  default = 0.25
}

variable "az_container_app_guexit_frontend_memory"{
  description = "The number of memory to allocate to Guexit Game in Container Apps."
  type = string
  default = "0.5Gi"
}

variable "az_application_insights_sampling_rate"{
  description = "The number of memory to allocate to Guexit Game in Container Apps."
  type = number
  default = 100
}
