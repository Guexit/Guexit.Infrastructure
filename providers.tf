terraform {
  required_version = "~> 1.7.1"
  cloud {
    organization = "Guexit"
    workspaces {
      name = "prod"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.89.0"
      subscription_id   = ${var.azure_subscription_id}
      tenant_id         = ${var.azure_subscription_tenant_id}
      client_id         = ${var.azure_client_id}
      client_secret     = ${var.azure_subscription_client_secret}
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }
}

provider "azurerm" {
  features {}
}
