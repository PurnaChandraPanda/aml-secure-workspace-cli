
## Foundry Agent Service: Standard Agent Setup
- This template is an extension of [15b-private-network-standard-agent-setup-byovnet](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet).
- This will help create Standard Foundry setup in existing vnet, where it allows to bring in existing aoai.
- The existing aoai resource connection is created and managed in capability host.

### Variables

The variables listed below [must be provided](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence) when performing deploying the templates. The file example.tfvars provides a sample Terraform variables file that can be used.
- **resource_group_name_resources** - The name of the resource group where the resources created with this template will be depoyed to.
- **resource_group_name_dns** - This name of the resource group where the pre-existing Private DNS Zones have been deployed to.
- **subnet_id_agent** - The Azure resource ID of the subnet that will be delegated to the Agent service. This subnet must be delegated to Microsoft.App/environments prior to deployment of the resources.
- **subnet_id_private_endpoint** - This Azure resource id of the subnet where Private Endpoints created by this template will be deployed.
- **subscription_id_resources** - The subscription ID (ex: 55555555-5555-5555-5555-555555555555) that the resources created with this template will be deployed to.
- **subscription_id_infra** - The subscription ID (ex: 55555555-5555-5555-5555-555555555555) where the pre-existing Private DNS zones have been deployed to.
- **location** - The Azure region the resources will be deployed to. This must be the same region where the pre-existing virtual network has been deployed to.
- **existingAoaiResourceId** - The ARM resource id existing aoai.
- **aoaiConnectionName** - The connection name to be created for existig aoai.

## Key changes for existing aoai service

- Add AOAI connection for existing AOAI at project level

```
# Project connection -> Existing Azure OpenAI
resource "azapi_resource" "ai_project_connection_existing_aoai" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name      = var.aoaiConnectionName
  parent_id = azapi_resource.ai_foundry_project.id

  body = {
    properties = {
      category = "AzureOpenAI"
      target = local.aoaiEndpoint
      authType = "AAD"
      useWorkspaceManagedIdentity = true
      metadata = {
        ApiType = "Azure"
        resourceId = var.existingAoaiResourceId
        accountName = local.aoaiResourceName
      }
    }
  }

  depends_on = [
    azapi_resource.ai_foundry_project
  ]
}
```

- Create project capability host with existing aoai connection details

```
## Create the AI Foundry project capability host
##
resource "azapi_resource" "ai_foundry_project_capability_host" {
  provider = azapi.workload_subscription

  depends_on = [
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    azapi_resource.ai_project_connection_existing_aoai,
    time_sleep.wait_rbac
  ]
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        azapi_resource.ai_search.name
      ]
      storageConnections = [
        azurerm_storage_account.storage_account.name
      ]
      threadStorageConnections = [
        azurerm_cosmosdb_account.cosmosdb.name
      ]
      aiServicesConnections = [
        var.aoaiConnectionName
      ]
    }
  }
}
```

---

## Deploy the Terraform template

1. Fill in the required information for the variables listed in the example.tfvars file and rename the file to terraform.tfvars.

2. If performing the deployment interactively, log in to Az CLI with a user that has sufficient permissions to deploy the resources.

```bash
az login
```

3. Ensure the proper environmental variables are set for [AzApi](https://registry.terraform.io/providers/Azure/azapi/latest/docs) and [AzureRm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) providers. At a minimum, you must set the ARM_SUBSCRIPTION_ID environment variable to the subscription the Foundry resoruces will be deployed to. You can do this with the commands below:

Linux/MacOS
```bash
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

Windows
```cmd
set ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

PowerShell Command Prompt
```
$env:ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
```

4. Initialize Terraform

```bash
terraform init
```

5. Deploy the resources
```bash
terraform apply
```

## Architecture Overview

The architecture this deployment supports below resources deployed by these templates.

### Step-by-Step Provisioning Process (main.tf)

1. Create dependent resources for standard setup:
   - Create new Cosmos DB resource
   - Create new Azure Storage resource
   - Create new Azure AI Search resource

2. Create Azure AI Foundry Resource (Cognitive Services/accounts, kind=AIServices)

3. Create account-level connections:
   - Deploy GPT-4o or other agent-compatible model

4. Create private endpoints with DNS resolution for the Azure Resources: Azure Cosmos DB Account, Azure Storage Storage, Azure AI Search, and Azure AI Foundry

5. Create Project (Cognitive Services/accounts/project)

6. Create project connections:
   - Create project connection to Azure Storage account
   - Create project connection to Azure AI Search account
   - Create project connection to Cosmos DB account
   - Create project connection to existing AOAI service resource

7. Assign the project-managed identity (including for SMI) the following roles:
   - Cosmos DB Operator at the scope of the account level for the Cosmos DB account resource
   - Storage Account Contributor at the scope of the account level for the Storage Account resource

8. Set Account capability host with empty properties section.

9. Set Project capability host with properties: Cosmos DB, Azure Storage, AI Search connections, existing AOAI service connection.

10. Assign the Project Managed Identity (both for SMI and UMI) the following roles on the specified resource scopes:
   - Azure AI Search: Search Index Data Contributor, Search Service Contributor
   - Azure Blob Storage Container: <workspaceId>-azureml-blobstore: Storage Blob Data Contributor
   - Azure Blob Storage Container: <workspaceId>-agents-blobstore: Storage Blob Data Owner
   - Cosmos DB for NoSQL container: <'${projectWorkspaceId}>-thread-message-store: Cosmos DB Built-in Data Contributor
   - Cosmos DB for NoSQL container: <'${projectWorkspaceId}>-system-thread-message-store: Cosmos DB Built-in Data Contributor
   - Cosmos DB for NoSQL container: <'${projectWorkspaceId}>-agent-entity-store: Cosmos DB Built-in Data Contributor

The deployment creates an isolated network environment:

- **Private Endpoints:**
  - AI Foundry
  - AI Search
  - CosmosDB
  - Storage

### Post Deployment

1. Once all resources are provisioned, assign all developers who want to create/edit agents in the project the role: Azure AI User on the project scope.

### Core Components

1. **AI Foundry Resource**
   - Central orchestration point
   - Manages service connections
   - Network-isolated capability hosts
2. **AI Project**
   - Workspace configuration
   - Service integration
   - Agent deployment
3. **Supporting Services for Standard Agent Deployment**
   - Azure AI Search
   - CosmosDB
   - Storage Account

---

## Security Features

### Authentication & Authorization

- **Managed Identity**
  - Zero-trust security model
  - No credential storage
  - Platform-managed rotation

- **Role Assignments**
  - **Azure AI Search**
    - Search Index Data Contributor (`8ebe5a00-799e-43f5-93ac-243d3dce84a7`)
    - Search Service Contributor (`7ca78c08-252a-4471-8644-bb5ff32d4ba0`)
  - **Azure Storage Account**
    - Storage Blob Data Owner (`b7e6dc6d-f1e8-4753-8033-0f276bb0955b`)
    - Storage Queue Data Contributor (`974c5e8b-45b9-4653-ba55-5f855dd0fb88`) (if Azure Function tool enabled)
    - Two containers will automatically be provisioned during the create capability host process:
      - Azure Blob Storage Container: `<workspaceId>-azureml-blobstore`
        - Storage Blob Data Contributor
      - Azure Blob Storage Container: `<workspaceId>-agents-blobstore`
        - Storage Blob Data Owner
  - **Key Vault**
    - Key Vault Contributor (`f25e0fa2-a7c8-4377-a976-54943a77a395`)
    - Key Vault Secrets Officer (`b86a8fe4-44ce-4948-aee5-eccb2c155cd7`)
  - **Cosmos DB for NoSQL**
    - Cosmos DB Operator (`230815da-be43-4aae-9cb4-875f7bd000aa`)
    - Cosmos DB Built-in Data Contributor
    - Cosmos DB for NoSQL container: `<${projectWorkspaceId}>-thread-message-store`
    - Cosmos DB for NoSQL container: `<${projectWorkspaceId}>-agent-entity-store`

### Network Security

- Public network access disabled
- Private endpoints for all services
- Service endpoints for Azure services
- Network ACLs with deny by default

---

## Module Structure

```text
code/
├── data.tf                                         # Creates data objects for active subscription being deployed to and deployment security context
├── locals.tf                                       # Creates local variables for project GUID
├── main.tf                                         # Main deployment file        
├── outputs.tf                                      # Placeholder file for future outputs
├── providers.tf                                    # Terraform provider configuration 
├── example.tfvars                                  # Sample tfvars file
├── variables.tf                                    # Terraform variables
├── versions.tf                                     # Configures minimum Terraform version and versions for providers
```

