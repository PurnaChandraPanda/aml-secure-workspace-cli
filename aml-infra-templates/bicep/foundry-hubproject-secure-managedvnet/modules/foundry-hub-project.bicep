targetScope = 'resourceGroup'

param location string
param aiHubName string
param aiProjectName string
param applicationInsightsId string
param storageAccountId string
param keyVaultId string
param acrId string

@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param managedNetworkIsolationMode string

param tags object

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2026-03-15-preview' = {
  name: aiHubName
  location: location
  kind: 'Hub'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: aiHubName

    applicationInsights: applicationInsightsId
    storageAccount: storageAccountId
    keyVault: keyVaultId
    containerRegistry: acrId

    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false

    // Same intent as Terraform: allow hub identity role-assignment/setup scenario.
    allowRoleAssignmentOnRG: true

    // Ask RP to provision the managed network.
    provisionNetworkNow: true

    managedNetwork: {
      isolationMode: managedNetworkIsolationMode
      managedNetworkKind: 'V1'
    }
  }
}

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2026-03-15-preview' = {
  name: aiProjectName
  location: location
  kind: 'Project'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: aiProjectName

    // Project belongs to hub.
    hubResourceId: aiHub.id

    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false
  }
}

output aiHubId string = aiHub.id
output aiHubName string = aiHub.name
output aiHubPrincipalId string = aiHub.identity.principalId

output aiProjectId string = aiProject.id
output aiProjectName string = aiProject.name
output aiProjectPrincipalId string = aiProject.identity.principalId