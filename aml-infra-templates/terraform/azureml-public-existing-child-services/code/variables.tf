
############################
# Variables
############################

variable "subscription_id" {
  type        = string
  description = "Subscription ID where the AML workspace will be created."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the AML workspace will be created."
}

variable "location" {
  type        = string
  description = "Azure region for the AML workspace."
}

variable "workspace_name" {
  type        = string
  description = "Name of the Azure ML workspace."
}

variable "friendly_name" {
  type        = string
  description = "Friendly name for the AML workspace."
  default     = null
}

variable "description" {
  type        = string
  description = "Description for the AML workspace."
  default     = null
}

variable "application_insights_id" {
  type        = string
  description = "ARM resource ID of the existing Application Insights resource."
}

variable "key_vault_id" {
  type        = string
  description = "ARM resource ID of the existing Key Vault."
}

variable "storage_account_id" {
  type        = string
  description = "ARM resource ID of the existing Storage Account."
}

variable "container_registry_id" {
  type        = string
  description = "ARM resource ID of the existing Azure Container Registry."
}

variable "public_network_access" {
  type        = string
  description = "Whether public network access is Enabled or Disabled."
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.public_network_access)
    error_message = "public_network_access must be either Enabled or Disabled."
  }
}

variable "system_datastores_auth_mode" {
  type        = string
  description = "Auth mode for system datastores."
  default     = "AccessKey"

  validation {
    condition     = contains(["AccessKey", "Identity", "UserDelegationSAS"], var.system_datastores_auth_mode)
    error_message = "system_datastores_auth_mode must be AccessKey, Identity, or UserDelegationSAS."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the AML workspace."
  default     = {}
}
