output "network_resource_group_name" {
  value = local.network_resource_group_id
}

output "platform_resource_group_name" {
  value = local.platform_resource_group_id
}

output "vnet_id" {
  value = local.vnet_id
}

output "private_endpoint_subnet_id" {
  value = local.private_endpoint_subnet_id
}

output "private_dns_zone_ids" {
  value = local.private_dns_zone_ids
}

output "aml_workspace_name" {
  value = azapi_resource.aml_workspace.name
}

output "aml_workspace_id" {
  value = azapi_resource.aml_workspace.id
}

output "aml_workspace_principal_id" {
  value = azapi_resource.aml_workspace.output.identity.principalId
}

output "storage_account_name" {
  value = azapi_resource.storage.name
}

output "key_vault_name" {
  value = azapi_resource.key_vault.name
}

output "acr_name" {
  value = azapi_resource.acr.name
}

output "managed_network_isolation_mode" {
  value = var.aml_managed_network_isolation_mode
}