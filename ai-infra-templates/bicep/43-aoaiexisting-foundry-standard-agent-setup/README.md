## Foundry Agent Service: Standard Agent Setup with byo AOAI
- This template assumes that user already has Standard Foundry exists in own vnet.
- This template is actually an extension of the template discussed in [43-standard-agent-setup-with-customization](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/43-standard-agent-setup-with-customization).
- On the existing Standard Foundry setup in vnet, it will have connection added for existing aoai.
- As the Foundry exists here, it means capability host exists here too.
- By design, capability host is immutable.

**Note:**
- So, once this template adds the connection for existing aoai, next step is to delete the project capability host, create capability host with ai service connection details again.
- With tf or bicep, the caphost can't be updated. So, need to take help of scripts to get caphost updated.

- Your existing Azure OpenAI resource must be in the sample region as you deploy the template.

## Key changes for existing aoai service

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

---

## Deploy Foundry Standard template - with connection

Add the connection for AOAI in Foundry project.

### Variables
- **foundryAccountName** - The name of the existing Foundry account resource.
- **projectName** - The name of the existing Foundry account based project resource.
- **existingAoaiResourceId** - The ARM resource id existing aoai.
- **aoaiConnectionName** - The connection name to be created for existig aoai.
- **isSharedToAll** - The flag to indicate whether connection is shared across all projects or specific project only.

### Manual deployment from the CLI

1. Create (or pick) a resource group:

```bash
    az group create --name <rg-name> --location <azure-region>
```

2. Deploy the Bicep template:

- Pass parameters to a parameter file: `main.bicepparam`.
- Deploy the bicep template to create connection for existing AOAI.

```bash
    az deployment group create --resource-group "rg-stdfoundry" --template-file main.bicep --parameters main.bicepparam
```

3. Update the project caphost layer with expected aoai connection. The details are discussed in [scripts-caphost](./scripts-caphost/readme.md).

## Troubleshooting

### Deployment issues from git bash
You may hit a Git Bash (MSYS) path-conversion bug, not a Cosmos/RBAC bug.

In Git Bash on Windows, any argument that starts with a leading / can get auto-translated into a Windows path (POSIX -> Windows conversion). Azure resource IDs start with /subscriptions/..., so Git Bash mangles them into something like:
C:/Program Files/Git/subscriptions/...
Azure CLI explicitly documents this "auto-translation of Resource IDs" issue in Git Bash and recommends disabling path conversion. 

Solution is to reset the path conversation flag, i.e. set the no path conversation flag to TRUE. Then, try other code in git bash level.

```
export MSYS_NO_PATHCONV=1
```

### Foundy agent data access issues

With v2 agent flow, sometimes data access level error is noticed for cosmos target resource. At that time, try the following tests on roles assigned for the MSI on target cosmosdb.

- List roles on cosmos db for principal id, i.e. Foundry Project MSI
```
az cosmosdb sql role assignment list \
  --account-name "aifoundry3385cosmosdb" \
  --resource-group "rg-stdfoundry3" \
  --query "[?principalId=='4e8a---------------------97b7']" -o table
```

- Per error message for container in cosmos (data level access), assign the data access for respective container. Apply for correct scope.

```
az cosmosdb sql role assignment create \
  --account-name "aifoundry3385cosmosdb" \
  --resource-group "rg-stdfoundry3" \
  --principal-id "4e8-----------------------------97b7" \
  --role-definition-id "/subscriptions/697------------------32103/resourceGroups/rg-stdfoundry3/providers/Microsoft.DocumentDB/databaseAccounts/aifoundry3385cosmosdb/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" \
  --scope "/dbs/enterprise_memory/colls/a8f4549b-3b13-4531-aea1-09f2b013d87c-agent-definitions-v1"
```

```
az cosmosdb sql role assignment create \
  --account-name "aifoundry3385cosmosdb" \
  --resource-group "rg-stdfoundry3" \
  --principal-id "4e8-----------------------------97b7" \
  --role-definition-id "/subscriptions/697------------------32103/resourceGroups/rg-stdfoundry3/providers/Microsoft.DocumentDB/databaseAccounts/aifoundry3385cosmosdb/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" \
  --scope "/dbs/enterprise_memory/colls/a8f4549b-3b13-4531-aea1-09f2b013d87c-run-state-v1"
```

