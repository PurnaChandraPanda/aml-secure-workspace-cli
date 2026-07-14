targetScope = 'subscription'

@allowed([
  'eastus'
  'swedencentral'
  'uksouth'
])
param location string = 'swedencentral'

param workspacePrefix string
param networkResourceGroupName string
param discoveryResourceGroupName string

@allowed([
  'create'
  'existing'
  'existingVnetCreateSubnets'
])
@description('Network mode for this deployment.')
param networkMode string = 'existingVnetCreateSubnets'

param vnetName string
param vnetAddressPrefix string

param agentSubnetPrefix string
param workspaceSubnetPrefix string
param privateEndpointSubnetPrefix string
param searchSubnetPrefix string
param aksSubnetPrefix string
param supercomputerNodepoolSubnetPrefix string
param storagePrivateEndpointSubnetPrefix string

@description('Required only when networkMode=existing.')
param existingVnetId string = ''

@description('Required only when networkMode=existing.')
param existingAgentSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingWorkspaceSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingPrivateEndpointSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingSearchSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingAksSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingSupercomputerNodepoolSubnetId string = ''

@description('Required only when networkMode=existing.')
param existingStoragePrivateEndpointSubnetId string = ''

param managedIdentityName string
param storageAccountName string
param blobContainerName string

param supercomputerName string
param nodePoolName string
param workspaceName string

@description('Existing Private DNS zone ARM ID for Discovery workspace data-plane. Empty means create in network RG.')
param workspacePrivateDnsZoneId string = ''

@description('Existing Private DNS zone ARM ID for Storage Blob. Empty means create in network RG.')
param blobPrivateDnsZoneId string = ''

@description('If true, create Private DNS zones in network RG when DNS zone IDs are empty.')
param createPrivateDnsZonesWhenMissing bool = true

@description('Whether this deployment should create VNet links in the existing DNS zones. Set false if central DNS team already linked/federated DNS.')
param createPrivateDnsVnetLinks bool = false

@description('Subscription ID where the existing Private DNS zones live. Required only if createPrivateDnsVnetLinks=true.')
param privateDnsZoneSubscriptionId string = subscription().subscriptionId

@description('Resource group where the existing Private DNS zones live. Required only if createPrivateDnsVnetLinks=true.')
param privateDnsZoneResourceGroupName string = networkResourceGroupName


resource networkRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: networkResourceGroupName
  location: location
}

resource discoveryRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: discoveryResourceGroupName
  location: location
}

module networkCreate './modules/network.bicep' = if (networkMode == 'create') {
  name: 'network-create-${uniqueString(networkResourceGroupName, workspacePrefix)}'
  scope: networkRg
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    workspacePrefix: workspacePrefix

    agentSubnetPrefix: agentSubnetPrefix
    workspaceSubnetPrefix: workspaceSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    searchSubnetPrefix: searchSubnetPrefix
    aksSubnetPrefix: aksSubnetPrefix
    supercomputerNodepoolSubnetPrefix: supercomputerNodepoolSubnetPrefix
    storagePrivateEndpointSubnetPrefix: storagePrivateEndpointSubnetPrefix

    workspacePrivateDnsZoneId: workspacePrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
    createPrivateDnsZonesWhenMissing: createPrivateDnsZonesWhenMissing
  }
}

module networkExisting './modules/network-existing.bicep' = if (networkMode == 'existing') {
  name: 'network-existing-${uniqueString(networkResourceGroupName, workspacePrefix)}'
  scope: networkRg
  params: {
    vnetId: existingVnetId

    agentSubnetId: existingAgentSubnetId
    workspaceSubnetId: existingWorkspaceSubnetId
    privateEndpointSubnetId: existingPrivateEndpointSubnetId
    searchSubnetId: existingSearchSubnetId
    aksSubnetId: existingAksSubnetId
    supercomputerNodepoolSubnetId: existingSupercomputerNodepoolSubnetId
    storagePrivateEndpointSubnetId: existingStoragePrivateEndpointSubnetId

    workspacePrivateDnsZoneId: workspacePrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
  }
}

module networkExistingVnetCreateSubnets './modules/network-existing-vnet-create-subnets.bicep' = if (networkMode == 'existingVnetCreateSubnets') {
  name: 'network-existing-vnet-create-subnets-${uniqueString(networkResourceGroupName, workspacePrefix)}'
  scope: networkRg
  params: {
    vnetName: vnetName
    workspacePrefix: workspacePrefix

    agentSubnetPrefix: agentSubnetPrefix
    workspaceSubnetPrefix: workspaceSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    searchSubnetPrefix: searchSubnetPrefix
    aksSubnetPrefix: aksSubnetPrefix
    supercomputerNodepoolSubnetPrefix: supercomputerNodepoolSubnetPrefix
    storagePrivateEndpointSubnetPrefix: storagePrivateEndpointSubnetPrefix

    workspacePrivateDnsZoneId: workspacePrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
  }
}

var effectiveVnetId = networkMode == 'create'
  ? networkCreate.outputs.vnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.vnetId
    : networkExistingVnetCreateSubnets.outputs.vnetId

var effectiveAgentSubnetId = networkMode == 'create'
  ? networkCreate.outputs.agentSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.agentSubnetId
    : networkExistingVnetCreateSubnets.outputs.agentSubnetId

var effectiveWorkspaceSubnetId = networkMode == 'create'
  ? networkCreate.outputs.workspaceSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.workspaceSubnetId
    : networkExistingVnetCreateSubnets.outputs.workspaceSubnetId

var effectivePrivateEndpointSubnetId = networkMode == 'create'
  ? networkCreate.outputs.privateEndpointSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.privateEndpointSubnetId
    : networkExistingVnetCreateSubnets.outputs.privateEndpointSubnetId

var effectiveSearchSubnetId = networkMode == 'create'
  ? networkCreate.outputs.searchSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.searchSubnetId
    : networkExistingVnetCreateSubnets.outputs.searchSubnetId

var effectiveAksSubnetId = networkMode == 'create'
  ? networkCreate.outputs.aksSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.aksSubnetId
    : networkExistingVnetCreateSubnets.outputs.aksSubnetId

var effectiveSupercomputerNodepoolSubnetId = networkMode == 'create'
  ? networkCreate.outputs.supercomputerNodepoolSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.supercomputerNodepoolSubnetId
    : networkExistingVnetCreateSubnets.outputs.supercomputerNodepoolSubnetId

var effectiveStoragePrivateEndpointSubnetId = networkMode == 'create'
  ? networkCreate.outputs.storagePrivateEndpointSubnetId
  : networkMode == 'existing'
    ? networkExisting.outputs.storagePrivateEndpointSubnetId
    : networkExistingVnetCreateSubnets.outputs.storagePrivateEndpointSubnetId

var effectiveWorkspacePrivateDnsZoneId = networkMode == 'create'
  ? networkCreate.outputs.effectiveWorkspacePrivateDnsZoneId
  : networkMode == 'existing'
    ? networkExisting.outputs.effectiveWorkspacePrivateDnsZoneId
    : networkExistingVnetCreateSubnets.outputs.effectiveWorkspacePrivateDnsZoneId

var effectiveBlobPrivateDnsZoneId = networkMode == 'create'
  ? networkCreate.outputs.effectiveBlobPrivateDnsZoneId
  : networkMode == 'existing'
    ? networkExisting.outputs.effectiveBlobPrivateDnsZoneId
    : networkExistingVnetCreateSubnets.outputs.effectiveBlobPrivateDnsZoneId

module base './modules/base.bicep' = {
  name: 'base-${uniqueString(discoveryResourceGroupName)}'
  scope: discoveryRg
  params: {
    location: location
    managedIdentityName: managedIdentityName
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    supercomputerName: supercomputerName
    nodePoolName: nodePoolName
    aksSubnetId: effectiveAksSubnetId
    supercomputerNodepoolSubnetId: effectiveSupercomputerNodepoolSubnetId
  }
  dependsOn: [
    discoveryRg
  ]
}

module workspaceBootstrap './modules/workspace-bootstrap.bicep' = {
  name: 'workspace-bootstrap-${uniqueString(workspaceName)}'
  scope: discoveryRg
  params: {
    location: location
    workspaceName: workspaceName

    managedIdentityId: base.outputs.managedIdentityId
    supercomputerId: base.outputs.supercomputerId

    agentSubnetId: effectiveAgentSubnetId
    workspaceSubnetId: effectiveWorkspaceSubnetId
    privateEndpointSubnetId: effectivePrivateEndpointSubnetId
  }
  dependsOn: [
    base
  ]
}

module privateEndpoints './modules/private-endpoints.bicep' = {
  name: 'private-endpoints-${uniqueString(workspaceName)}'
  scope: discoveryRg
  params: {
    location: location
    
    workspaceName: workspaceName
    workspaceId: workspaceBootstrap.outputs.workspaceId
    
    storageAccountName: storageAccountName
    storageAccountId: base.outputs.storageAccountId
  
    // Subnets can still be in the network RG/VNet
    privateEndpointSubnetId: effectivePrivateEndpointSubnetId
    storagePrivateEndpointSubnetId: effectiveStoragePrivateEndpointSubnetId

    workspacePrivateDnsZoneId: effectiveWorkspacePrivateDnsZoneId
    blobPrivateDnsZoneId: effectiveBlobPrivateDnsZoneId
  }
  dependsOn: [
    workspaceBootstrap
    base
  ]
}

module dnsLinks './modules/dns-links.bicep' = if (createPrivateDnsVnetLinks) {
  name: 'dns-links-${uniqueString(networkResourceGroupName, vnetName)}'
  scope: resourceGroup(privateDnsZoneSubscriptionId, privateDnsZoneResourceGroupName)

  params: {
    vnetId: effectiveVnetId
    vnetName: vnetName
    workspacePrivateDnsZoneName: 'privatelink.workspace.discovery.azure.com'
    blobPrivateDnsZoneName: 'privatelink.blob.core.windows.net'
  }
}


output workspaceId string = workspaceBootstrap.outputs.workspaceId
output workspacePrivateEndpointId string = privateEndpoints.outputs.workspacePrivateEndpointId
output storagePrivateEndpointId string = privateEndpoints.outputs.storagePrivateEndpointId
output storageAccountId string = base.outputs.storageAccountId
