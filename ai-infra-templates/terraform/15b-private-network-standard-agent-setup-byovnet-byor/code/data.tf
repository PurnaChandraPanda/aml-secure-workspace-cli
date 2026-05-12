data "azurerm_storage_account" "existing_storage_account" {
  count    = var.existing_storage_account_id != null ? 1 : 0
  provider = azurerm.workload_subscription

  name                = local.storage_account_name
  resource_group_name = local.storage_account_rg_name
}

data "azurerm_cosmosdb_account" "existing_cosmos_account" {
  count    = var.existing_cosmos_account_id != null ? 1 : 0
  provider = azurerm.workload_subscription

  name                = local.cosmos_account_name
  resource_group_name = local.cosmos_account_rg_name
}

## For Search, you can often avoid a data source because your connection target is already built from name (https://<name>.search.windows.net), but you do need the local name/id fixed
