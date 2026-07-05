locals {
  suffix = random_string.suffix.result

  # Existing RGs
  network_resource_group_id  = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.network_resource_group_name}"
  platform_resource_group_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  # DNS zone canonical names
  private_dns_zone_names = {
    aml_api       = "privatelink.api.azureml.ms"
    aml_notebooks = "privatelink.notebooks.azure.net"
    storage_blob  = "privatelink.blob.core.windows.net"
    storage_file  = "privatelink.file.core.windows.net"
    key_vault     = "privatelink.vaultcore.azure.net"
    acr           = "privatelink.azurecr.io"
    monitor       = "privatelink.monitor.azure.com"
    oms           = "privatelink.oms.opinsights.azure.com"
    ods           = "privatelink.ods.opinsights.azure.com"
    agentsvc      = "privatelink.agentsvc.azure-automation.net"
  }

  # Create only zones not supplied in existing_private_dns_zone_ids.
  private_dns_zones_to_create = {
    for key, zone_name in local.private_dns_zone_names :
    key => zone_name
    if !contains(keys(var.existing_private_dns_zone_ids), key)
  }

  # VNet ID selection:
  # - If create_vnet=true, use created VNet.
  # - Else use existing_vnet_id.
  vnet_id = var.create_vnet ? azapi_resource.vnet[0].id : var.existing_vnet_id

  # PE subnet ID selection:
  # - If create_private_endpoint_subnet=true, use created subnet.
  # - Else use existing_private_endpoint_subnet_id.
  private_endpoint_subnet_id = var.create_private_endpoint_subnet ? azapi_resource.subnet_private_endpoints[0].id : var.existing_private_endpoint_subnet_id

  resource_names = {
    vnet          = "vnet-${var.prefix}-${local.suffix}"
    pe_subnet     = "snet-private-endpoints"
    storage       = substr(lower(replace("st${var.prefix}${local.suffix}", "-", "")), 0, 24)
    key_vault     = substr(lower("kv-${var.prefix}-${local.suffix}"), 0, 24)
    acr           = substr(lower(replace("cr${var.prefix}${local.suffix}", "-", "")), 0, 50)
    log_analytics = "log-${var.prefix}-${local.suffix}"
    app_insights  = "appi-${var.prefix}-${local.suffix}"
    aml_workspace = "mlw-${var.prefix}-${local.suffix}"
    ampls         = "ampls-${var.prefix}-${local.suffix}"
  }

  approved_outbound_enabled = var.aml_managed_network_isolation_mode == "AllowOnlyApprovedOutbound"

  role_definition_ids = {
    storage_blob_data_contributor            = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    storage_file_data_privileged_contributor = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/69566ab7-960f-475b-8e7c-b3118f30c6bd"
    acr_pull                                 = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d"
    key_vault_secrets_user                   = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
  }

  created_private_dns_zone_ids = {
    for key, zone in azapi_resource.private_dns_zones :
    key => zone.id
  }

  private_dns_zone_ids = merge(
    local.created_private_dns_zone_ids,
    var.existing_private_dns_zone_ids
  )

  # For ampls
  ampls_id = var.existing_ampls_id != null ? var.existing_ampls_id : azapi_resource.ampls[0].id

}