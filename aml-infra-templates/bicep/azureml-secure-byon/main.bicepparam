using './main.bicep'

// Azure region where regional resources are deployed.
param location = 'eastus2'

// Short name prefix used to generate resource names such as workspace, storage, key vault, and ACR.
param prefix = 'amlsec'

// Resource group that contains or receives network resources such as VNet, private endpoints, and Private DNS zones.
param networkResourceGroupName = 'rg-pupanda1-vnet'

// Resource group where the AzureML workspace and dependent platform resources are deployed.
param platformResourceGroupName = 'rg-pupanda6'

// Storage account replication option for the workspace default storage account.
param storageReplicationType = 'LRS'

// ACR SKU. Premium is required for private endpoint support.
param acrSku = 'Premium'

// Tags applied to resources created by this deployment.
param tags = {
  workload: 'azureml'
  environment: 'dev'
  owner: 'purna'
  managed_by: 'bicep'
}

// Set true to create a new VNet. Set false to reuse the VNet provided in existingVnetId.
param createVnet = false

// Existing VNet resource ID used when createVnet is false.
param existingVnetId = '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/virtualNetworks/vnet-amlsec-ekg0p3'

// Set true to create a private endpoint subnet. Set false to reuse existingPrivateEndpointSubnetId.
param createPrivateEndpointSubnet = false

// Existing subnet resource ID where private endpoints are created when createPrivateEndpointSubnet is false.
param existingPrivateEndpointSubnetId = '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/virtualNetworks/vnet-amlsec-ekg0p3/subnets/subnet2'

// Set false when Private DNS zone VNet links already exist or are managed outside this deployment.
param createPrivateDnsZoneVnetLinks = false

// Existing Private DNS zones to reuse. Any missing key is created by the private-dns module.
param existingPrivateDnsZoneIds = {
  // AzureML workspace API private endpoint zone.
  aml_api: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms'

  // AzureML notebooks private endpoint zone.
  aml_notebooks: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net'

  // Storage blob private endpoint zone.
  storage_blob: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'

  // Storage file private endpoint zone.
  storage_file: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net'

  // Key Vault private endpoint zone.
  key_vault: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

  // Azure Container Registry private endpoint zone.
  acr: '/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
}
