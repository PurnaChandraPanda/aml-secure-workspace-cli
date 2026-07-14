using './main.bicep'

// Discovery-supported region.
// Allowed in template: eastus, swedencentral, uksouth
param location = 'swedencentral'

// Must be 3-24 chars, alphanumeric and hyphens only
param supercomputerName = 'sc-demo-001'

// Must be 1-12 lowercase alphanumeric chars, starting with a letter
param nodePoolName = 'nodepool1'

// Must be 3-24 chars, alphanumeric and hyphens only
param workspaceName = 'ws-demo-001'

// Chat model deployment name
param chatModelDeploymentName = 'gpt-5-2'

// Must be 3-24 chars, alphanumeric and hyphens only
param storageContainerName = 'stc-demo-001'

// Must be 3-24 chars, alphanumeric and hyphens only
param projectName = 'prj-demo-001'

// Virtual network name
param vnetName = 'vnet-disc-demo-002'