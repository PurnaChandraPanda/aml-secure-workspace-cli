locals {
  project_id_guid = "${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 0, 8)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 8, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 12, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 16, 4)}-${substr(azapi_resource.ai_foundry_project.output.properties.internalId, 20, 12)}"

  
  storage_account_id = var.existing_storage_account_id != null ? var.existing_storage_account_id : azurerm_storage_account.storage_account[0].id
  search_service_id  = var.existing_search_service_id  != null ? var.existing_search_service_id  : azapi_resource.ai_search[0].id
  cosmos_account_id  = var.existing_cosmos_account_id  != null ? var.existing_cosmos_account_id  : azurerm_cosmosdb_account.cosmosdb[0].id

  storage_account_name = var.existing_storage_account_id != null ? element(reverse(split("/", var.existing_storage_account_id)), 0) : azurerm_storage_account.storage_account[0].name
  search_service_name  = var.existing_search_service_id  != null ? element(reverse(split("/", var.existing_search_service_id)), 0)  : azapi_resource.ai_search[0].name
  cosmos_account_name  = var.existing_cosmos_account_id  != null ? element(reverse(split("/", var.existing_cosmos_account_id)), 0)  : azurerm_cosmosdb_account.cosmosdb[0].name

  
  storage_account_rg_name = var.existing_storage_account_id != null ? split("/", var.existing_storage_account_id)[4] : var.resource_group_name_resources
  cosmos_account_rg_name  = var.existing_cosmos_account_id  != null ? split("/", var.existing_cosmos_account_id)[4]  : var.resource_group_name_resources

  storage_blob_endpoint = var.existing_storage_account_id != null ? data.azurerm_storage_account.existing_storage_account[0].primary_blob_endpoint : azurerm_storage_account.storage_account[0].primary_blob_endpoint
  cosmos_endpoint       = var.existing_cosmos_account_id  != null ? data.azurerm_cosmosdb_account.existing_cosmos_account[0].endpoint             : azurerm_cosmosdb_account.cosmosdb[0].endpoint


}
