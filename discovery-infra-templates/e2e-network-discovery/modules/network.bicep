targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Customer-owned VNet name to create or update.')
param vnetName string

@description('VNet address prefix.')
param vnetAddressPrefix string

@description('Prefix for this Discovery workspace subnet slice, for example uks6demo006.')
param workspacePrefix string

@description('Agent workload subnet CIDR.')
param agentSubnetPrefix string

@description('Workspace services subnet CIDR.')
param workspaceSubnetPrefix string

@description('Workspace data-plane private endpoint subnet CIDR.')
param privateEndpointSubnetPrefix string

@description('Bookshelf/search subnet CIDR.')
param searchSubnetPrefix string

@description('Supercomputer AKS/system subnet CIDR.')
param aksSubnetPrefix string

@description('Supercomputer nodepool subnet CIDR.')
param supercomputerNodepoolSubnetPrefix string

@description('Customer storage private endpoint subnet CIDR.')
param storagePrivateEndpointSubnetPrefix string

@description('Existing Private DNS zone ARM ID for Discovery workspace data-plane. Leave empty to create in this network RG.')
param workspacePrivateDnsZoneId string = ''

@description('Existing Private DNS zone ARM ID for Storage Blob. Leave empty to create in this network RG.')
param blobPrivateDnsZoneId string = ''

@description('Create Private DNS zones in this network RG when DNS zone IDs are empty.')
param createPrivateDnsZonesWhenMissing bool = true

var agentSubnetName = '${workspacePrefix}-agent-ws'
var workspaceSubnetName = '${workspacePrefix}-workspace-ws'
var privateEndpointSubnetName = '${workspacePrefix}-pe-ws'
var searchSubnetName = '${workspacePrefix}-bs-search'
var aksSubnetName = '${workspacePrefix}-sc-aks'
var supercomputerNodepoolSubnetName = '${workspacePrefix}-sc-nodepool'
var storagePrivateEndpointSubnetName = '${workspacePrefix}-pe-storage'

var createWorkspaceDnsZone = createPrivateDnsZonesWhenMissing && empty(workspacePrivateDnsZoneId)
var createBlobDnsZone = createPrivateDnsZonesWhenMissing && empty(blobPrivateDnsZoneId)

var appEnvDelegation = {
  name: 'Microsoft.App.environments'
  properties: {
    serviceName: 'Microsoft.App/environments'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource agentSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: agentSubnetName
  properties: {
    addressPrefix: agentSubnetPrefix
    delegations: [
      appEnvDelegation
    ]
  }
}

resource workspaceSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: workspaceSubnetName
  properties: {
    addressPrefix: workspaceSubnetPrefix
    delegations: [
      appEnvDelegation
    ]
  }
  dependsOn: [
    agentSubnet
  ]
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: privateEndpointSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    workspaceSubnet
  ]
}

resource searchSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: searchSubnetName
  properties: {
    addressPrefix: searchSubnetPrefix
    delegations: [
      appEnvDelegation
    ]
  }
  dependsOn: [
    privateEndpointSubnet
  ]
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: aksSubnetName
  properties: {
    addressPrefix: aksSubnetPrefix
  }
  dependsOn: [
    searchSubnet
  ]
}

resource supercomputerNodepoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: supercomputerNodepoolSubnetName
  properties: {
    addressPrefix: supercomputerNodepoolSubnetPrefix
  }
  dependsOn: [
    aksSubnet
  ]
}

resource storagePrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: storagePrivateEndpointSubnetName
  properties: {
    addressPrefix: storagePrivateEndpointSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    supercomputerNodepoolSubnet
  ]
}

resource workspaceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createWorkspaceDnsZone) {
  name: 'privatelink.workspace.discovery.azure.com'
  location: 'global'
}

resource workspaceDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createWorkspaceDnsZone) {
  parent: workspaceDnsZone
  name: '${vnetName}-workspace-discovery-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource blobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createBlobDnsZone) {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource blobDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createBlobDnsZone) {
  parent: blobDnsZone
  name: '${vnetName}-blob-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output vnetId string = vnet.id

output agentSubnetId string = agentSubnet.id
output workspaceSubnetId string = workspaceSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output searchSubnetId string = searchSubnet.id
output aksSubnetId string = aksSubnet.id
output supercomputerNodepoolSubnetId string = supercomputerNodepoolSubnet.id
output storagePrivateEndpointSubnetId string = storagePrivateEndpointSubnet.id

output effectiveWorkspacePrivateDnsZoneId string = createWorkspaceDnsZone
  ? workspaceDnsZone.id
  : workspacePrivateDnsZoneId

output effectiveBlobPrivateDnsZoneId string = createBlobDnsZone
  ? blobDnsZone.id
  : blobPrivateDnsZoneId
