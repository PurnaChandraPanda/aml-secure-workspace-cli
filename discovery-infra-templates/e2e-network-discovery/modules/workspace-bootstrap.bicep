targetScope = 'resourceGroup'

param location string
param workspaceName string

param managedIdentityId string
param supercomputerId string

param agentSubnetId string
param workspaceSubnetId string
param privateEndpointSubnetId string

resource workspace 'Microsoft.Discovery/workspaces@2026-06-01' = {
  name: workspaceName
  location: location
  tags: {
    version: 'v2'
    networkMode: 'pna-disabled-from-create'
  }
  properties: {
    publicNetworkAccess: 'Disabled'

    workspaceIdentity: {
      id: managedIdentityId
    }

    supercomputerIds: [
      supercomputerId
    ]

    agentSubnetId: agentSubnetId
    workspaceSubnetId: workspaceSubnetId
    privateEndpointSubnetId: privateEndpointSubnetId
  }
}

output workspaceId string = workspace.id
