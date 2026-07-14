using './project.bicep'

// Pass location where discovery worksapce is created
param location = 'uksouth'

// Pass existing discovery worksapce name
param workspaceName = 'ws-uks8demo-008'

// Pass storage account craeted in discovery RG
param storageAccountId = '/subscriptions/69---------------------------03/resourceGroups/rg-uks8discovery/providers/Microsoft.Storage/storageAccounts/stguks8discovery001'

param projectName = 'prj-demo-008'

param chatModelDeploymentName = 'gpt-5-2'
param chatModelName = 'gpt-5.2'

param storageContainerName = 'stc-demo-008'
