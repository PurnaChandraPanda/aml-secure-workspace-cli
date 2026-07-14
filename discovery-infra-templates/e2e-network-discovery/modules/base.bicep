targetScope = 'resourceGroup'

param location string

param managedIdentityName string
param storageAccountName string
param blobContainerName string

param supercomputerName string
param nodePoolName string

param aksSubnetId string
param supercomputerNodepoolSubnetId string

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var discoveryPlatformContributorRoleId = '01288891-85ee-45a7-b367-9db3b752fc65'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: managedIdentityName
  location: location
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true

    // Strict policy mode: keep public network access disabled from creation.
    publicNetworkAccess: 'Disabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: blobContainerName
}

resource storageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, uami.id, storageBlobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource discoveryPlatformContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, uami.id, discoveryPlatformContributorRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', discoveryPlatformContributorRoleId)
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, uami.id, acrPullRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource supercomputer 'Microsoft.Discovery/supercomputers@2026-06-01' = {
  name: supercomputerName
  location: location
  tags: {
    version: 'v2'
  }
  properties: {
    subnetId: aksSubnetId
    
    identities: {
      clusterIdentity: {
        id: uami.id
      }
      kubeletIdentity: {
        id: uami.id
      }
      workloadIdentities: {
          '${uami.id}': {}
      }
    }
  }
  dependsOn: [
    discoveryPlatformContributorAssignment
    acrPullAssignment
  ]
}

resource nodePool 'Microsoft.Discovery/supercomputers/nodePools@2026-06-01' = {
  parent: supercomputer
  name: nodePoolName
  location: location
  properties: {
    subnetId: supercomputerNodepoolSubnetId

    vmSize: 'Standard_D4s_v6'
    maxNodeCount: 3
    minNodeCount: 0
    scaleSetPriority: 'Regular'
  }
}

output managedIdentityId string = uami.id
output managedIdentityPrincipalId string = uami.properties.principalId
output storageAccountId string = storage.id
output supercomputerId string = supercomputer.id
output nodePoolId string = nodePool.id