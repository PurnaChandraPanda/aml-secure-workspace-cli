targetScope = 'resourceGroup'

@description('Existing customer-owned VNet name.')
param vnetName string

@description('Prefix for this Discovery workspace subnet slice, for example uks7demo007.')
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

@description('Existing Private DNS zone ARM ID for Discovery workspace data-plane.')
param workspacePrivateDnsZoneId string

@description('Existing Private DNS zone ARM ID for Storage Blob.')
param blobPrivateDnsZoneId string

var agentSubnetName = '${workspacePrefix}-agent-ws'
var workspaceSubnetName = '${workspacePrefix}-workspace-ws'
var privateEndpointSubnetName = '${workspacePrefix}-pe-ws'
var searchSubnetName = '${workspacePrefix}-bs-search'
var aksSubnetName = '${workspacePrefix}-sc-aks'
var supercomputerNodepoolSubnetName = '${workspacePrefix}-sc-nodepool'
var storagePrivateEndpointSubnetName = '${workspacePrefix}-pe-storage'

var appEnvDelegation = {
  name: 'Microsoft.App.environments'
  properties: {
    serviceName: 'Microsoft.App/environments'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
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
  // To overcome 429 in subnets parallel create time, chain it, so that one after other will be created.
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

output vnetId string = vnet.id

output agentSubnetId string = agentSubnet.id
output workspaceSubnetId string = workspaceSubnet.id
output privateEndpointSubnetId string = privateEndpointSubnet.id
output searchSubnetId string = searchSubnet.id
output aksSubnetId string = aksSubnet.id
output supercomputerNodepoolSubnetId string = supercomputerNodepoolSubnet.id
output storagePrivateEndpointSubnetId string = storagePrivateEndpointSubnet.id

output effectiveWorkspacePrivateDnsZoneId string = workspacePrivateDnsZoneId
output effectiveBlobPrivateDnsZoneId string = blobPrivateDnsZoneId
