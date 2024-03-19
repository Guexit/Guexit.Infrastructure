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
  description = "Azure subscription tenant id."
  type = string
}
variable "azure_subscription_client_secret"{
  description = "Azure subscription tenant id."
  type = string
}



