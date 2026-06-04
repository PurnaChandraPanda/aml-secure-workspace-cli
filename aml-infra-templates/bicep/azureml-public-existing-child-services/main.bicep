@description('Name of the Azure Machine Learning workspace.')
param workspaceName string

@description('Azure region for the workspace.')
param location string = resourceGroup().location

@description('Friendly name for the Azure ML workspace.')
param friendlyName string = workspaceName

@description('Optional description for the workspace.')
param workspaceDescription string = ''

@description('ARM resource ID of the existing Application Insights resource.')
param applicationInsightsResourceId string

@description('ARM resource ID of the existing Azure Container Registry resource.')
param containerRegistryResourceId string

@description('ARM resource ID of the existing Key Vault resource.')
param keyVaultResourceId string

@description('ARM resource ID of the existing Storage Account resource.')
param storageAccountResourceId string

@allowed([
  'Enabled'
  'Disabled'
])
@description('Whether public network access is enabled for the workspace.')
param publicNetworkAccess string = 'Enabled'

@allowed([
  'AccessKey'
  'Identity'
  'UserDelegationSAS'
])
@description('Authentication mode used for the system datastores.')
param systemDatastoresAuthMode string = 'AccessKey'

@description('Optional tags for the workspace.')
param tags object = {}

resource amlWorkspace 'Microsoft.MachineLearningServices/workspaces@2026-03-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    friendlyName: friendlyName
    description: workspaceDescription
    applicationInsights: applicationInsightsResourceId
    containerRegistry: containerRegistryResourceId
    keyVault: keyVaultResourceId
    storageAccount: storageAccountResourceId
    publicNetworkAccess: publicNetworkAccess
    systemDatastoresAuthMode: systemDatastoresAuthMode
    v1LegacyMode: false
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

output workspaceId string = amlWorkspace.id
output workspaceNameOut string = amlWorkspace.name
output workspacePrincipalId string = amlWorkspace.identity.principalId
