targetScope = 'resourceGroup'

@description('Azure region.')
param location string = resourceGroup().location

@description('Existing Microsoft Discovery workspace name.')
param workspaceName string

@description('Existing Azure Storage account resource ID used by Discovery storage container.')
param storageAccountId string

@description('Existing Microsoft Discovery storage container resource name.')
param storageContainerName string

@description('Chat model deployment name under the workspace.')
param chatModelDeploymentName string

@description('Chat model name.')
param chatModelName string

@description('Microsoft Discovery project name.')
param projectName string

resource workspace 'Microsoft.Discovery/workspaces@2026-06-01' existing = {
  name: workspaceName
}

resource discoveryStorageContainer 'Microsoft.Discovery/storageContainers@2026-06-01' = {
  name: storageContainerName
  location: location
  properties: {
    storageStore: {
      kind: 'AzureStorageBlob'
      storageAccountId: storageAccountId
    }
  }
}

resource chatModelDeployment 'Microsoft.Discovery/workspaces/chatModelDeployments@2026-06-01' = {
  parent: workspace
  name: chatModelDeploymentName
  location: location
  properties: {
    modelFormat: 'OpenAI'
    modelName: chatModelName
  }
}

resource project 'Microsoft.Discovery/workspaces/projects@2026-06-01' = {
  parent: workspace
  name: projectName
  location: location
  properties: {
    storageContainerIds: [
      discoveryStorageContainer.id
    ]
  }
  dependsOn: [
    chatModelDeployment
    discoveryStorageContainer
  ]
}

output discoveryStorageContainerId string = discoveryStorageContainer.id
output chatModelDeploymentId string = chatModelDeployment.id
output projectId string = project.id