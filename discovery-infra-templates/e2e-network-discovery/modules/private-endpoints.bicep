targetScope = 'resourceGroup'

param location string

param workspaceName string
param workspaceId string

param storageAccountName string
param storageAccountId string

param privateEndpointSubnetId string
param storagePrivateEndpointSubnetId string

@description('Effective Private DNS zone ARM ID for Discovery workspace data-plane.')
param workspacePrivateDnsZoneId string

@description('Effective Private DNS zone ARM ID for Storage Blob.')
param blobPrivateDnsZoneId string


resource workspacePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${workspaceName}-workspace'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'workspace'
        properties: {
          privateLinkServiceId: workspaceId
          groupIds: [
            'workspace'
          ]
        }
      }
    ]
  }
}

resource workspacePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: workspacePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'workspace'
        properties: {
          privateDnsZoneId: workspacePrivateDnsZoneId
        }
      }
    ]
  }
}

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${storageAccountName}-blob'
  location: location
  properties: {
    subnet: {
      id: storagePrivateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'blob'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZoneId
        }
      }
    ]
  }
}

output workspacePrivateEndpointId string = workspacePrivateEndpoint.id
output storagePrivateEndpointId string = storagePrivateEndpoint.id
