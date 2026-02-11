## Foundry Agent Service: Standard Agent Setup with BYO AOAI
- This template is actually an extension of the template discussed in [15-private-network-standard-agent-setup](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup).
- This template will create a new Standard Foundry in own vnet.
- As the project is created from scratch, the project caphost is created from scratch.
- Before the project caphost is created, connection is created for existing aoai. Same connection is used in ai service connection to create the project caphost.

**Note:**
- So, once this template adds the connection for existing aoai, it will create capability host with ai service connection details.

- Your existing Azure OpenAI resource must be in the sample region as you deploy the template.

## Key change for existing AOAI
- In [existing-vnet.bicep](./modules-network-secured/existing-vnet.bicep), add a validation layer, i.e. whether user opted for using existing subnets.

```
// Create the agent subnet if requested
module agentSubnet 'subnet.bicep' = if(!useExistingSubnets) {
  name: 'agent-subnet-${uniqueString(deployment().name, agentSubnetName)}'
  scope: resourceGroup(vnetResourceGroupName)
  params: {
    vnetName: vnetName
    subnetName: agentSubnetName
    addressPrefix: agentSubnetSpaces
    delegations: [
      {
        name: 'Microsoft.App/environments'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

// Create the private endpoint subnet if requested
module peSubnet 'subnet.bicep' = if(!useExistingSubnets) {
  name: 'pe-subnet-${uniqueString(deployment().name, peSubnetName)}'
  scope: resourceGroup(vnetResourceGroupName)
  params: {
    vnetName: vnetName
    subnetName: peSubnetName
    addressPrefix: peSubnetSpaces
    delegations: []
  }
}
```

## Key changes for existing AOAI service

- Add project level connection for existing aoai.

```
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
```

- Create project capability host with existing aoai connection.

```
// Compute an optional value for the caphost parameter
var aiServicesConnectionOpt = !empty(existingAoaiResourceId) ? aoaiConnectionName : null

// This module creates the capability host for the project and account
module addProjectCapabilityHost 'modules-network-secured/add-project-capability-host.bicep' = {
  name: 'capabilityHost-configuration-${uniqueSuffix}-deployment'
  params: {
    accountName: aiAccount.outputs.accountName
    projectName: aiProject.outputs.projectName
    cosmosDBConnection: aiProject.outputs.cosmosDBConnection
    azureStorageConnection: aiProject.outputs.azureStorageConnection
    aiSearchConnection: aiProject.outputs.aiSearchConnection
    projectCapHost: projectCapHost
    aiServicesConnection: aiServicesConnectionOpt
  }
  dependsOn: [
     aiSearch      // Ensure AI Search exists
     storage       // Ensure Storage exists
     cosmosDB
     privateEndpointAndDNS
     cosmosAccountRoleAssignments
     storageAccountRoleAssignment
     aiSearchRoleAssignments
     // This dependsOn is safe even if addAoaiConn is skipped.
     addAoaiConn
  ]
}
```

```
// AOAI project connection name if null to skip
param aiServicesConnection string?

var aiServicesConnections = empty(aiServicesConnection)? []: ['${aiServicesConnection}']

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: projectCapHost
  parent: project
  properties: {
    capabilityHostKind: 'Agents'
    vectorStoreConnections: vectorStoreConnections
    storageConnections: storageConnections
    threadStorageConnections: threadConnections
    aiServicesConnections: aiServicesConnections
  }

}
```

## Variables

- **location** - Location where Foundry account is to be created
- **aiServices** - Foundry account resource name
- **firstProjectName** - Foundry project resource name
- **existingVnetResourceId** - ARM ID of existing VNET resource
- **vnetName**  - VNE name of existing VNET resource
- **useExistingSubnets** - Set the flag true if want to use existing subnets
- **agentSubnetName** - Provide existing subnet name in vnet where microsoft.app/environment delegation is created
- **peSubnetName** - Provide existing subnet name in vnet responsible for PEs
- **existingAoaiResourceId** - Provide ARM id of AOAI resource
- **aoaiConnectionName** - Provide connection name for existing AOAI
- **isSharedToAll** - Set the flag to indicate whether conn is shared among projects or specific project
- **dnsZonesSubscriptionId** - Provide the subscription id where DNS zones are kept

**Note:** 
- If you ll keep `existingAoaiResourceId` and `aoaiConnectionName`, then no connection will be created for AOAI in Foundry.
- If you ll supply `dnsZonesSubscriptionId`, rememeber to update `existingDnsZones` with resource group value where these DNS zones exist.

---

## Deploy the bicep template

- Create a New (or Use Existing) Resource Group

   ```bash
   az group create --name <new-rg-name> --location <your-rg-region>
   ```
  
- Deploy the main.bicep file
  - Edit the main.bicepparams file to use an existing Virtual Network & subnets, AOAI arm id and related.

   ```bash
      az deployment group create --resource-group "rg-stdfoundry" --template-file main.bicep --parameters main.bicepparam
   ```

**Note:** To access your Foundry resource securely, use either a VM, VPN, or ExpressRoute.

---

## Module Structure

```text
modules-network-secured/
├── add-project-capability-host.bicep               # Configuring the project's capability host
├── ai-account-identity.bicep                       # Azure AI Foundry deployment and configuration
├── ai-project-identity.bicep                       # Foundry project deployment and connection configuration           
├── ai-search-role-assignments.bicep                # AI Search RBAC configuration
├── azure-storage-account-role-assignments.bicep    # Storage Account RBAC configuration  
├── blob-storage-container-role-assignments.bicep   # Blob Storage Container RBAC configuration
├── cosmos-container-role-assignments.bicep         # CosmosDB container Account RBAC configuration
├── cosmosdb-account-role-assignment.bicep          # CosmosDB Account RBAC configuration
├── existing-vnet.bicep                             # Bring your existing virtual network to template deployment
├── format-project-workspace-id.bicep               # Formatting the project workspace ID
├── network-agent-vnet.bicep                        # Logic for routing virtual network set-up if existing virtual network is selected
├── private-endpoint-and-dns.bicep                  # Creating virtual networks and DNS zones. 
├── standard-dependent-resources.bicep              # Deploying CosmosDB, Storage, and Search
├── subnet.bicep                                    # Setting the subnet for Agent network injection
├── validate-existing-resources.bicep               # Validate existing CosmosDB, Storage, and Search to template deployment
└── vnet.bicep                                      # Deploying a new virtual network
└── add-aoai-connection.bicep                       # Add connection for existing aoai
```

> **Note:** If you bring your own VNET for this template, ensure the subnet for Agents has the correct subnet delegation to `Microsoft.App/environments`. If you have not specified the delegated subnet, the template will complete this for you.

## Order for add existing aoai connection
- Create the Foundry account (Cognitive Services account).
- Create the Foundry project (child of the account).
- Create all project‑scoped connections (Storage, Cosmos, AI Search, your AOAI connection).
- Create the capability host(s) using connection names:
  - account‑level (if your template does that first), then
  - project‑level capability host with aiServicesConnections: [ '<your-connection-name>' ]. 
- Capability hosts take connection names (strings), not resource IDs, and they are not updatable—delete & recreate to change them.


   ```bash
      az deployment group create --resource-group 'rg-stdfoundry42' --template-file main.bicep --parameters main.bicepparam
   ```

