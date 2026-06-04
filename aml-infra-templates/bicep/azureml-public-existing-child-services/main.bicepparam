using './main.bicep'

// Supply new ML workspace name
param workspaceName = 'amlws-prod2-001'
// Location of new ML workspace
param location = 'westeurope'

// ML workspace friendly name and description
param friendlyName = 'AML Workspace Prod'
param workspaceDescription = 'Azure ML workspace using existing KV, Storage, ACR and App Insights'

// ARM IDs of application insights, KV, storage account, ACR
param applicationInsightsResourceId = '/subscriptions/6977e-----------------------2103/resourceGroups/my-rg/providers/microsoft.insights/components/myappinsightsname'
param keyVaultResourceId = '/subscriptions/6977e-----------------------2103/resourceGroups/my-rg/providers/Microsoft.KeyVault/vaults/mykvname'
param storageAccountResourceId = '/subscriptions/6977e-----------------------2103/resourceGroups/my-rg/providers/Microsoft.Storage/storageAccounts/mystoragename'
param containerRegistryResourceId = '/subscriptions/6977e-----------------------2103/resourceGroups/my-rg/providers/Microsoft.ContainerRegistry/registries/myacrname'

// Set PNA param
param publicNetworkAccess = 'Enabled'

// Set datastore auth value
param systemDatastoresAuthMode = 'Identity'

// Set tags
param tags = {
  environment: 'prod'
  workload: 'azureml'
}
