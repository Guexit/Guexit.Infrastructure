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
