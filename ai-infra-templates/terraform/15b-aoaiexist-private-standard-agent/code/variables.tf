variable "subscription_id" {
  description = "Subscription id where foundry is kept"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the existing resource group with foundry account"
  type        = string
}

variable "foundry_account_name" {
  description = "The name of the existing foundry account"
  type        = string
}

variable "foundry_project_name" {
  description = "The name of the existing foundry project"
  type        = string
}

variable "existingAoaiResourceId" {
  type        = string
  description = "ARM ID of existing Azure OpenAI (Microsoft.CognitiveServices/accounts kind=OpenAI)"
}

variable "aoaiConnectionName" {
  type        = string
  description = "Name of the project connection to the existing Azure OpenAI resource"
}

