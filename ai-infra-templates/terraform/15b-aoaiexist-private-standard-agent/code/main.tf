

# Project connection -> Existing Azure OpenAI
resource "azapi_resource" "ai_project_connection_existing_aoai" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name      = var.aoaiConnectionName
  parent_id = data.azapi_resource.foundry_project.id

  body = {
    properties = {
      category = "AzureOpenAI"
      target = local.aoaiEndpoint
      authType = "AAD"
      useWorkspaceManagedIdentity = true
      metadata = {
        ApiType = "Azure"
        resourceId = var.existingAoaiResourceId
        accountName = local.aoaiResourceName
      }
    }
  }

  depends_on = [
    data.azapi_resource.foundry_project
  ]
}
