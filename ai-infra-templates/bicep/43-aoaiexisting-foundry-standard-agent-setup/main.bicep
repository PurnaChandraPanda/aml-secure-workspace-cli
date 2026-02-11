
@description('Foundry account name (Microsoft.CognitiveServices/accounts).')
param foundryAccountName string

@description('Foundry project name (Microsoft.CognitiveServices/accounts/projects).')
param projectName string

@description('Existing Azure OpenAI ARM resource id (Microsoft.CognitiveServices/accounts).')
param existingAoaiResourceId string

@description('Connection name to create under the Foundry project.')
param aoaiConnectionName string = 'existing-aoai'

@description('Share AOAI connection to all projects/users (optional).')
param isSharedToAll bool = false

// ---- caphost recreate inputs (deploymentScripts) ----

@description('API version used inside deploymentScripts for caphost endpoints.')
param apiVersion string = '2025-06-01'

// If your deployment script needs subscriptionId explicitly
param subscriptionId string = subscription().subscriptionId


// 1) Create AOAI connection under Foundry Project
module addAoaiConn './modules/add-aoai-connection.bicep' = {
  name: 'addAoaiConnection'
  params: {
    foundryAccountName: foundryAccountName
    projectName: projectName
    existingAoaiResourceId: existingAoaiResourceId
    aoaiConnectionName: aoaiConnectionName
    isSharedToAll: isSharedToAll
  }
}


// Convenience outputs
output aoaiProjectConnectionName string = addAoaiConn.outputs.createdConnectionName
output aoaiProjectConnectionId string = addAoaiConn.outputs.createdConnectionId
