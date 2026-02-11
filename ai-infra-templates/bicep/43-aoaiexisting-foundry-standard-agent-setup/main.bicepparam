using './main.bicep'

// Foundry account name
param foundryAccountName = 'aifoundry1231'
// Foundry project name
param projectName = 'project1231'

// ARM resource id of existing AOAI
param existingAoaiResourceId = '/subscriptions/6977------------532103/resourceGroups/rg-stdfoundry/providers/Microsoft.CognitiveServices/accounts/new1aoai'
// Connection name to create for existing AOAI
param aoaiConnectionName = 'existing4-aoai'
// Flag whether the aoai connection to be shared with other projects or current project only
param isSharedToAll = false


