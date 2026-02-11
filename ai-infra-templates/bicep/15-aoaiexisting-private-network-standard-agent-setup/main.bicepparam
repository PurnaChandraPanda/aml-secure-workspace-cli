using './main.bicep'

param location = 'eastus2'
param aiServices = 'foundry597' // Foundry account name
param modelName = 'gpt-4.1'
param modelFormat = 'OpenAI'
param modelVersion = '2025-04-14'
param modelSkuName = 'GlobalStandard'
param modelCapacity = 30
param firstProjectName = 'project597' // Foundry project name
param projectDescription = 'A project for the AI Foundry account with network secured deployed Agent'
param displayName = 'project'

// Resource IDs for existing resources
// If you provide these, the deployment will use the existing resources instead of creating new ones
param existingVnetResourceId = '/subscriptions/697------------32103/resourceGroups/rg-eus2vnet45/providers/Microsoft.Network/virtualNetworks/eus2vnetabyo'
param vnetName = 'eus2vnetabyo'
param useExistingSubnets = true // Set the flag true if want to use existing subnets
param agentSubnetName = 'default32' // existing subnet in vnet where microsoft.app/environment delegation is created
param peSubnetName = 'default' // existing subnet in vnet responsible for PEs
param aiSearchResourceId = ''
param azureStorageAccountResourceId = ''
param azureCosmosDBAccountResourceId = ''

// Existing aoai resource id, connection name, isSharedToAll - feed all values
param existingAoaiResourceId = '/subscriptions/697-----------------------------103/resourceGroups/rg-stdfoundry/providers/Microsoft.CognitiveServices/accounts/new1aoai'
param aoaiConnectionName = 'existing11-aoai'
param isSharedToAll = false

// param existingAoaiResourceId = ''
// param aoaiConnectionName = ''

// Subscription ID where DNS zones are located (leave empty to use deployment subscription)
// ⚠️ If set to a different subscription, ALL zones below MUST have resource groups specified
param dnsZonesSubscriptionId = '6977---------------------32103'

// DNS zone map: provide resource group name to use existing zone, or leave empty to create new
// Note: Empty values only allowed when dnsZonesSubscriptionId is empty or matches current subscription
param existingDnsZones = {
  'privatelink.services.ai.azure.com': 'rg-eus2vnet45'
  'privatelink.openai.azure.com': 'rg-eus2vnet45'
  'privatelink.cognitiveservices.azure.com': 'rg-eus2vnet45'          
  'privatelink.search.windows.net': 'rg-eus2vnet45'           
  'privatelink.blob.core.windows.net': 'rg-eus2vnet45'                            
  'privatelink.documents.azure.com': 'rg-eus2vnet45'                       
}

//DNSZones names for validating if they exist
param dnsZoneNames = [
  'privatelink.services.ai.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.search.windows.net'
  'privatelink.blob.core.windows.net'
  'privatelink.documents.azure.com'
]


// Network configuration (behavior depends on `existingVnetResourceId`)
//
// - NEW VNet (existingVnetResourceId is empty):
//     The values below are used to CREATE the VNet and the two subnets.
//     Provide explicit, non-overlapping CIDR ranges when creating a new VNet.
//
// - EXISTING VNet (existingVnetResourceId is provided):
//     The module will reference the existing VNet. Subnet handling depends on the
//     values you provide:
//       * If `agentSubnetPrefix` or `peSubnetPrefix` are empty, the module may
//         auto-derive subnet CIDRs from the existing VNet's address space
//         (using cidrSubnet). This can produce /24 (or configured) subnets
//         starting at index 0, 1, etc.
//       * If you provide explicit subnet prefixes, the module will attempt to
//         create or update subnets with those prefixes in the existing VNet.
//
// Important operational notes and risks (when existingVnetResourceId is provided):
// - Avoid CIDR overlaps with any existing subnets in the target VNet. Overlap
//   leads to `NetcfgSubnetRangesOverlap` and failed deployments.
// - For highest safety when using an existing VNet, supply the existing `agentSubnetPrefix` and `peSubnetPrefix`. 
param vnetAddressPrefix = ''
param agentSubnetPrefix = ''
param peSubnetPrefix = ''

