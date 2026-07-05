targetScope = 'resourceGroup'

param location string
param createVnet bool
param existingVnetId string
param vnetName string
param vnetAddressPrefixes array
param createPrivateEndpointSubnet bool
param existingPrivateEndpointSubnetId string
param privateEndpointSubnetName string
param privateEndpointSubnetPrefixes array
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = if (createVnet) {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
  }
}

var resolvedVnetId = createVnet ? vnet.id : existingVnetId

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = if (createPrivateEndpointSubnet) {
  name: '${last(split(resolvedVnetId, '/'))}/${privateEndpointSubnetName}'
  properties: {
    addressPrefixes: privateEndpointSubnetPrefixes
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

output vnetId string = resolvedVnetId
output privateEndpointSubnetId string = createPrivateEndpointSubnet ? peSubnet.id : existingPrivateEndpointSubnetId
