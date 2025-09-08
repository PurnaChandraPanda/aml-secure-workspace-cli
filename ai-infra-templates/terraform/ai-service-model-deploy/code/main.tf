terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">=1.5.0"
    }
  }
}

provider "azapi" {
  # Configure authentication as needed
}


resource "azapi_resource" "model_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-06-01"
  name      = "${var.deployment_name}"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/${var.account_name}"

  body = {
    sku = {
      name     = var.sku_name
      capacity = var.capacity
    }
    properties = {
      model = {
        format  = var.model_publisher_format
        name    = var.model_name
        version = var.model_version
      }
      raiPolicyName = var.content_filter_policy_name != null ? var.content_filter_policy_name : "Microsoft.Nill"
    }
  }

  # Optional: export the full response for debugging
  response_export_values = ["*"]
}
