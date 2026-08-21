targetScope = 'resourceGroup'

param location string
param privateEndpointName string
param privateServiceConnectionName string
param targetResourceId string
param groupIds array
param subnetId string
param privateDnsZoneIds array
param privateDnsZoneConfigNames array
param tags object

resource pe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateServiceConnectionName
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
          requestMessage: 'Private endpoint created by Bicep'
        }
      }
    ]
  }
}

resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: 'default'
  parent: pe
  properties: {
    privateDnsZoneConfigs: [
      for (zoneId, i) in privateDnsZoneIds: {
        name: privateDnsZoneConfigNames[i]
        properties: {
          privateDnsZoneId: zoneId
        }
      }
    ]
  }
}

output privateEndpointId string = pe.id