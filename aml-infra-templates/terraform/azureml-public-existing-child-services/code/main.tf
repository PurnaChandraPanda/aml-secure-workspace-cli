
############################
# Azure ML Workspace
############################

resource "azapi_resource" "aml_workspace" {
  type      = "Microsoft.MachineLearningServices/workspaces@2026-03-01"
  name      = var.workspace_name
  parent_id = data.azurerm_resource_group.rg.id
  location  = var.location

  identity {
    type         = "SystemAssigned"
    identity_ids = []
  }

  tags = var.tags

  body = {
    properties = {
      applicationInsights      = var.application_insights_id
      containerRegistry        = var.container_registry_id
      keyVault                 = var.key_vault_id
      storageAccount           = var.storage_account_id
      friendlyName             = var.friendly_name
      description              = var.description
      publicNetworkAccess      = var.public_network_access
      systemDatastoresAuthMode = var.system_datastores_auth_mode
      v1LegacyMode             = false
    }
    sku = {
      name = "Basic"
      tier = "Basic"
    }
  }

  # Commonly used with AzAPI resources
  schema_validation_enabled = false
  response_export_values    = ["*"]
  ignore_casing             = true
}

############################
# Outputs
############################

output "workspace_id" {
  value = azapi_resource.aml_workspace.id
}

output "workspace_name" {
  value = azapi_resource.aml_workspace.name
}

output "workspace_principal_id" {
  value = try(azapi_resource.aml_workspace.output.identity.principalId, null)
}
