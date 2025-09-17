variable "subscription_id" {
  description = "Subscription id where the Cognitive Services account exists"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the Cognitive Services account exists"
  type        = string
}

variable "account_name" {
  description = "Name of the Azure AI services account"
  type        = string
}

variable "deployment_name" {
  description = "Name of the model deployment (child resource under the AI Service)"
  type        = string
}

variable "model_name" {
  description = "Name of the model to deploy"
  type        = string
}

variable "model_version" {
  description = "Version of the model to deploy"
  type        = string
}

variable "model_publisher_format" {
  description = "Model provider"
  type        = string
  validation {
    condition     = contains(["AI21 Labs", "Cohere", "Core42", "DeepSeek", "xAI", "Meta", "Microsoft", "Mistral AI", "OpenAI", "OpenAI-OSS"], var.model_publisher_format)
    error_message = "Invalid model provider."
  }
}

variable "sku_name" {
  description = "Model deployment SKU name"
  type        = string
  default     = "GlobalStandard"
}

variable "capacity" {
  description = "Model deployment capacity"
  type        = number
  default     = 250
}

variable "content_filter_policy_name" {
  description = "Content filter policy name"
  type        = string
  default     = "Microsoft.DefaultV2"
}
