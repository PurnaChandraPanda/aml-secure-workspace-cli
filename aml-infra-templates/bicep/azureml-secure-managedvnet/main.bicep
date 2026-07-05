targetScope = 'subscription'

@description('Azure region for all regional resources.')
param location string = 'eastus2'

@description('Short lowercase prefix for resource names.')
@minLength(3)
@maxLength(12)
param prefix string

@description('Network resource group. Expected to exist.')
param networkResourceGroupName string

@description('Platform resource group. Expected to exist.')
param platformResourceGroupName string

@description('Whether to create a new VNet.')
param createVnet bool = true

@description('Existing VNet resource ID. Required when createVnet=false unless existingPrivateEndpointSubnetId is supplied.')
param existingVnetId string = ''

@description('VNet address prefixes if creating a new VNet.')
param vnetAddressPrefixes array = [
  '10.50.0.0/16'
]

@description('Whether to create a private endpoint subnet.')
param createPrivateEndpointSubnet bool = true

@description('Existing private endpoint subnet resource ID. Required when createPrivateEndpointSubnet=false.')
param existingPrivateEndpointSubnetId string = ''

@description('Private endpoint subnet prefixes if creating subnet.')
param privateEndpointSubnetPrefixes array = [
  '10.50.10.0/24'
]

@description('Azure ML managed VNet outbound mode.')
@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param amlManagedNetworkIsolationMode string = 'AllowOnlyApprovedOutbound'

@description('Storage replication type.')
@allowed([
  'LRS'
  'GRS'
  'RAGRS'
  'ZRS'
  'GZRS'
  'RAGZRS'
])
param storageReplicationType string = 'LRS'

@description('ACR SKU. Premium is recommended/required for private endpoint support.')
@allowed([
  'Premium'
])
param acrSku string = 'Premium'

@description('Use existing Private DNS zone IDs where available. Missing keys are created.')
param existingPrivateDnsZoneIds object = {}

@description('Whether this deployment should create VNet links for Private DNS zones.')
param createPrivateDnsZoneVnetLinks bool = true

@description('Whether to create a private endpoint for AMPLS. Set false if the VNet is already connected to an AMPLS private endpoint.')
param createAmplsPrivateEndpoint bool = false

@description('Resource group where AMPLS exists or should be created.')
param amplsResourceGroupName string = platformResourceGroupName

@description('Existing AMPLS resource ID. If empty, a new AMPLS is created.')
param existingAmplsId string = ''

@description('Common tags.')
param tags object = {
  workload: 'azureml'
  environment: 'dev'
  managed_by: 'bicep'
}

var suffix = uniqueString(subscription().id, platformResourceGroupName, networkResourceGroupName, prefix)

var names = {
  vnet: 'vnet-${prefix}-${suffix}'
  peSubnet: 'snet-private-endpoints'
  storage: take(toLower(replace('st${prefix}${suffix}', '-', '')), 24)
  keyVault: take(toLower('kv-${prefix}-${suffix}'), 24)
  acr: take(toLower(replace('cr${prefix}${suffix}', '-', '')), 50)
  logAnalytics: 'log-${prefix}-${suffix}'
  appInsights: 'appi-${prefix}-${suffix}'
  amlWorkspace: 'mlw-${prefix}-${suffix}'
  ampls: 'ampls-${prefix}-${suffix}'
}

var networkRg = resourceGroup(networkResourceGroupName)
var platformRg = resourceGroup(platformResourceGroupName)

module network './modules/network.bicep' = {
  name: 'network-${suffix}'
  scope: networkRg
  params: {
    location: location
    createVnet: createVnet
    existingVnetId: existingVnetId
    vnetName: names.vnet
    vnetAddressPrefixes: vnetAddressPrefixes
    createPrivateEndpointSubnet: createPrivateEndpointSubnet
    existingPrivateEndpointSubnetId: existingPrivateEndpointSubnetId
    privateEndpointSubnetName: names.peSubnet
    privateEndpointSubnetPrefixes: privateEndpointSubnetPrefixes
    tags: tags
  }
}

var resolvedVnetId = network.outputs.vnetId
var resolvedPrivateEndpointSubnetId = network.outputs.privateEndpointSubnetId

module dns './modules/private-dns.bicep' = {
  name: 'dns-${suffix}'
  scope: networkRg
  params: {
    vnetId: resolvedVnetId
    existingPrivateDnsZoneIds: existingPrivateDnsZoneIds
    createPrivateDnsZoneVnetLinks: createPrivateDnsZoneVnetLinks
    linkSuffix: suffix
    tags: tags
  }
}

module monitor './modules/monitor.bicep' = {
  name: 'monitor-${suffix}'
  scope: platformRg
  params: {
    location: location
    logAnalyticsName: names.logAnalytics
    appInsightsName: names.appInsights
    tags: tags
  }
}

module platform './modules/platform-resources.bicep' = {
  name: 'platform-${suffix}'
  scope: platformRg
  params: {
    location: location
    storageName: names.storage
    keyVaultName: names.keyVault
    acrName: names.acr
    storageReplicationType: storageReplicationType
    acrSku: acrSku
    tags: tags
  }
}

module aml './modules/aml-workspace.bicep' = {
  name: 'aml-${suffix}'
  scope: platformRg
  params: {
    location: location
    amlWorkspaceName: names.amlWorkspace
    applicationInsightsId: monitor.outputs.appInsightsId
    storageAccountId: platform.outputs.storageAccountId
    keyVaultId: platform.outputs.keyVaultId
    acrId: platform.outputs.acrId
    amlManagedNetworkIsolationMode: amlManagedNetworkIsolationMode
    tags: tags
  }
}

module peAml './modules/private-endpoint.bicep' = {
  name: 'pe-aml-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.amlWorkspace}'
    privateServiceConnectionName: 'psc-${names.amlWorkspace}'
    targetResourceId: aml.outputs.amlWorkspaceId
    groupIds: [
      'amlworkspace'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.aml_api
      dns.outputs.privateDnsZoneIds.aml_notebooks
    ]
    privateDnsZoneConfigNames: [
      'aml-api'
      'aml-notebooks'
    ]
    tags: tags
  }
}

module peStorageBlob './modules/private-endpoint.bicep' = {
  name: 'pe-storage-blob-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.storage}-blob'
    privateServiceConnectionName: 'psc-${names.storage}-blob'
    targetResourceId: platform.outputs.storageAccountId
    groupIds: [
      'blob'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.storage_blob
    ]
    privateDnsZoneConfigNames: [
      'storage-blob'
    ]
    tags: tags
  }
}

module peStorageFile './modules/private-endpoint.bicep' = {
  name: 'pe-storage-file-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.storage}-file'
    privateServiceConnectionName: 'psc-${names.storage}-file'
    targetResourceId: platform.outputs.storageAccountId
    groupIds: [
      'file'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.storage_file
    ]
    privateDnsZoneConfigNames: [
      'storage-file'
    ]
    tags: tags
  }
}

module peKeyVault './modules/private-endpoint.bicep' = {
  name: 'pe-kv-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.keyVault}'
    privateServiceConnectionName: 'psc-${names.keyVault}'
    targetResourceId: platform.outputs.keyVaultId
    groupIds: [
      'vault'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.key_vault
    ]
    privateDnsZoneConfigNames: [
      'keyvault'
    ]
    tags: tags
  }
}

module peAcr './modules/private-endpoint.bicep' = {
  name: 'pe-acr-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.acr}'
    privateServiceConnectionName: 'psc-${names.acr}'
    targetResourceId: platform.outputs.acrId
    groupIds: [
      'registry'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.acr
    ]
    privateDnsZoneConfigNames: [
      'acr'
    ]
    tags: tags
  }
}

module ampls './modules/ampls.bicep' = {
  name: 'ampls-${suffix}'
  scope: resourceGroup(amplsResourceGroupName)
  params: {
    amplsName: names.ampls
    existingAmplsId: existingAmplsId
    tags: tags
  }
}

module amplsScopedResources './modules/ampls-scoped-resources.bicep' = {
  name: 'ampls-scoped-${suffix}'
  scope: resourceGroup(amplsResourceGroupName)
  params: {
    amplsName: ampls.outputs.amplsName
    logAnalyticsId: monitor.outputs.logAnalyticsId
    appInsightsId: monitor.outputs.appInsightsId
  }
}

module peAmpls './modules/private-endpoint.bicep' = if (createAmplsPrivateEndpoint) {
  name: 'pe-ampls-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.ampls}'
    privateServiceConnectionName: 'psc-${names.ampls}'
    targetResourceId: ampls.outputs.amplsId
    groupIds: [
      'azuremonitor'
    ]
    subnetId: resolvedPrivateEndpointSubnetId
    privateDnsZoneIds: [
      dns.outputs.privateDnsZoneIds.monitor
      dns.outputs.privateDnsZoneIds.oms
      dns.outputs.privateDnsZoneIds.ods
      dns.outputs.privateDnsZoneIds.agentsvc
      dns.outputs.privateDnsZoneIds.storage_blob
    ]
    privateDnsZoneConfigNames: [
      'monitor'
      'oms'
      'ods'
      'agentsvc'
      'blob'
    ]
    tags: tags
  }
}

output amlWorkspaceName string = names.amlWorkspace
output amlWorkspaceId string = aml.outputs.amlWorkspaceId
output storageAccountName string = names.storage
output keyVaultName string = names.keyVault
output acrName string = names.acr
output vnetId string = resolvedVnetId
output privateEndpointSubnetId string = resolvedPrivateEndpointSubnetId
