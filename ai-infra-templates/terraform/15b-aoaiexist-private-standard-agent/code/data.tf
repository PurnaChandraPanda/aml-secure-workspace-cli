
# 1) Look up the existing Foundry account
data "azapi_resource_id" "foundry_account" {
  type                = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                = var.foundry_account_name
  parent_id           = local.foundry_rg_id
}


# 2) Look up the existing Foundry project under that account
data "azapi_resource" "foundry_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = var.foundry_project_name
  parent_id = data.azapi_resource_id.foundry_account.id
}

