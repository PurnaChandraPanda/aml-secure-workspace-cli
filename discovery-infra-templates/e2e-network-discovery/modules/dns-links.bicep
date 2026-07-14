targetScope = 'resourceGroup'

@description('Customer-owned Discovery VNet resource ID.')
param vnetId string

@description('Customer-owned Discovery VNet name.')
param vnetName string

@description('Existing Discovery workspace Private DNS zone name.')
param workspacePrivateDnsZoneName string = 'privatelink.workspace.discovery.azure.com'

@description('Existing Storage Blob Private DNS zone name.')
param blobPrivateDnsZoneName string = 'privatelink.blob.core.windows.net'

resource workspaceDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: workspacePrivateDnsZoneName
}

resource blobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: blobPrivateDnsZoneName
}

resource workspaceDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: workspaceDnsZone
  name: '${vnetName}-workspace-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource blobDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: blobDnsZone
  name: '${vnetName}-blob-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output workspaceDnsVnetLinkId string = workspaceDnsVnetLink.id
output blobDnsVnetLinkId string = blobDnsVnetLink.id

