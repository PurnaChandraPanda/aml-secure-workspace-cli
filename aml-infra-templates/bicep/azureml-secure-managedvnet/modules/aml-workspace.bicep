targetScope = 'resourceGroup'

param location string
param amlWorkspaceName string
param applicationInsightsId string
param storageAccountId string
param keyVaultId string
param acrId string

@allowed([
  'AllowInternetOutbound'
  'AllowOnlyApprovedOutbound'
])
param amlManagedNetworkIsolationMode string

param tags object

resource aml 'Microsoft.MachineLearningServices/workspaces@2026-03-15-preview' = {
  name: amlWorkspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    applicationInsights: applicationInsightsId
    storageAccount: storageAccountId
    keyVault: keyVaultId
    containerRegistry: acrId
    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false

    // Triggers provisioning when managed VNet is enabled.
    provisionNetworkNow: true

    managedNetwork: {
      isolationMode: amlManagedNetworkIsolationMode
      managedNetworkKind: 'V1'
    }
  }
}

output amlWorkspaceId string = aml.id
output amlWorkspaceName string = aml.name
output amlPrincipalId string = aml.identity.principalId