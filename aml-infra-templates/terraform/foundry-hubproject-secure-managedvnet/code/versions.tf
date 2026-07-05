terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azapi" {
  skip_provider_registration = false
}