
@description('Foundry account name (Microsoft.CognitiveServices/accounts). Example: aifoundry1231')
param accountName string

@description('Foundry project name (Microsoft.CognitiveServices/accounts/projects).')
param projectName string

@description('Existing Azure OpenAI ARM resource id (Microsoft.CognitiveServices/accounts).')
param existingAoaiResourceId string

@description('Connection name to create under the project. (2-32 chars, alnum/_/-)')
param aoaiConnectionName string = 'existing-aoai'

@description('Share connection to all projects (optional).')
param isSharedToAll bool = false

// Parse AOAI ARM id: /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>
var aoaiParts = split(existingAoaiResourceId, '/')
var aoaiSubId = aoaiParts[2]
var aoaiRg    = aoaiParts[4]
var aoaiName  = aoaiParts[8]

// Existing Foundry account & project
resource foundry 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' existing = {
  parent: foundry
  name: projectName
}


// Existing RG in the AOAI subscription
resource aoaiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription(aoaiSubId)
  name:  aoaiRg
}

// Existing AOAI account (scoped to the correct RG/ subscription)
resource aoai 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  scope: aoaiResourceGroup
  name:  aoaiName
}

var aoaiEndpoint = aoai.properties.endpoint

/*
// Create Account Connection to Azure OpenAI
resource aoaiConn 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
  parent: foundry
  name: aoaiConnectionName
  properties: {
    category: 'AzureOpenAI'
    target: aoaiEndpoint

    // Recommended auth: Entra ID (AAD).
    authType: 'AAD'

    // This flag exists in the connection schema; keep true if you want MI-based auth behavior where supported.
    useWorkspaceManagedIdentity: true

    isSharedToAll: isSharedToAll
    metadata: {
        ApiType: 'Azure'
        resourceId: existingAoaiResourceId
        accountName: aoaiName
    }
  }
}
*/

// Create Project Connection to Azure OpenAI
resource aoaiConn 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: aoaiConnectionName
  properties: {
    category: 'AzureOpenAI'
    target: aoaiEndpoint

    // Recommended auth: Entra ID (AAD).
    authType: 'AAD'

    // This flag exists in the connection schema; keep true if you want MI-based auth behavior where supported.
    useWorkspaceManagedIdentity: true

    isSharedToAll: isSharedToAll
    metadata: {
        ApiType: 'Azure'
        resourceId: existingAoaiResourceId
        accountName: aoaiName
    }
  }
}

output createdConnectionId string = aoaiConn.id
output createdConnectionName string = aoaiConn.name
output aoaiTargetEndpoint string = aoaiEndpoint
