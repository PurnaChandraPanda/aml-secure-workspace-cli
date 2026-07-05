targetScope = 'subscription'

param location string = 'eastus2'
param prefix string

param networkResourceGroupName string
param platformResourceGroupName string
param amplsResourceGroupName string = platformResourceGroupName

param createVnet bool = false
param existingVnetId string = ''
param createPrivateEndpointSubnet bool = false
param existingPrivateEndpointSubnetId string = ''

param vnetAddressPrefixes array = [
  '10.50.0.0/16'
]

param privateEndpointSubnetPrefixes array = [
  '10.50.10.0/24'
]

@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param foundryManagedNetworkIsolationMode string = 'AllowOnlyApprovedOutbound'

param storageReplicationType string = 'LRS'
param acrSku string = 'Premium'

param existingPrivateDnsZoneIds object = {}
param createPrivateDnsZoneVnetLinks bool = false

param existingAmplsId string = ''
param createAmplsPrivateEndpoint bool = false

param tags object = {
  workload: 'ai-foundry'
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
  aiHub: 'hub-${prefix}-${suffix}'
  aiProject: 'proj-${prefix}-${suffix}'
  ampls: 'ampls-${prefix}-${suffix}'
}

var networkRg = resourceGroup(networkResourceGroupName)
var platformRg = resourceGroup(platformResourceGroupName)
var amplsRg = resourceGroup(amplsResourceGroupName)

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

module foundry './modules/foundry-hub-project.bicep' = {
  name: 'foundry-${suffix}'
  scope: platformRg
  params: {
    location: location
    aiHubName: names.aiHub
    aiProjectName: names.aiProject
    applicationInsightsId: monitor.outputs.appInsightsId
    storageAccountId: platform.outputs.storageAccountId
    keyVaultId: platform.outputs.keyVaultId
    acrId: platform.outputs.acrId
    managedNetworkIsolationMode: foundryManagedNetworkIsolationMode
    tags: tags
  }
}

module peAiHub './modules/private-endpoint.bicep' = {
  name: 'pe-aihub-${suffix}'
  scope: networkRg
  params: {
    location: location
    privateEndpointName: 'pe-${names.aiHub}'
    privateServiceConnectionName: 'psc-${names.aiHub}'
    targetResourceId: foundry.outputs.aiHubId
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
  scope: amplsRg
  params: {
    amplsName: names.ampls
    existingAmplsId: existingAmplsId
    tags: tags
  }
}

module amplsScopedResources './modules/ampls-scoped-resources.bicep' = {
  name: 'ampls-scoped-${suffix}'
  scope: amplsRg
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

output aiHubName string = names.aiHub
output aiHubId string = foundry.outputs.aiHubId
output aiHubPrincipalId string = foundry.outputs.aiHubPrincipalId

output aiProjectName string = names.aiProject
output aiProjectId string = foundry.outputs.aiProjectId
output aiProjectPrincipalId string = foundry.outputs.aiProjectPrincipalId

output storageAccountName string = names.storage
output keyVaultName string = names.keyVault
output acrName string = names.acr
output vnetId string = resolvedVnetId
output privateEndpointSubnetId string = resolvedPrivateEndpointSubnetId
