variable "resource_group_name_resources" {
  description = "The name of the existing resource group to deploy the resources into"
  type        = string
}

variable "resource_group_name_dns" {
  description = "The name of the existing resource group where the Private DNS Zones have been created"
  type        = string
}

variable "subnet_id_agent" {
  description = "The resource id of the subnet that has been delegated to Microsoft.Apps/environments"
  type        = string
}

variable "subnet_id_private_endpoint" {
  description = "The resource id of the subnet that will be used to deploy Private Endpoints to"
  type        = string
}

variable "subscription_id_infra" {
  description = "The subscription id where the Private DNS Zones are located"
  type        = string
}

variable "subscription_id_resources" {
  description = "The subscription id where the resources will be deployed"
  type        = string
}

variable "location" {
  description = "The name of the location to provision the resources to"
  type        = string
}

variable "existing_storage_account_id" {
  description = "ARM ID of existing storage account"
  type        = string
  default     = null
}

variable "existing_search_service_id" {
  description = "ARM ID of existing AI Search service account"
  type        = string
  default     = null
}

variable "existing_cosmos_account_id" {
  description = "ARM ID of existing Cosmos DB account"
  type        = string
  default     = null
}

variable "create_private_endpoints_for_existing_resources" {
  description = "Flag to create PE for existing resources"
  type        = bool
  default     = false
}

