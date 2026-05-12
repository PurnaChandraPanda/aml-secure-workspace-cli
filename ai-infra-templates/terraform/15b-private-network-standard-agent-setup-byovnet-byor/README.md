---
description: This set of templates demonstrates how to set up Azure AI Agent Service with virtual network isolation with private network links to connect the agent to your secure data using a pre-existing virtual network - with BYOR (for CosmosDB, AI Search, Storage Account).
page_type: sample
products:
- azure
- azure-resource-manager
urlFragment: network-secured-agent
languages:
- hcl
---

- This template is a re-work of [15b-private-network-standard-agent-setup-byovnet](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet) template, which supports BYOR onboarding.


## Prerequisites

1. **Active Azure subscription(s) with appropriate permissions**
  It's recommended to deploy these templates through a deployment pipeline associated to a service principal or managed identity with sufficient permissions over the the workload subscription (such as Owner or Role Based Access Control Administrator and Contributor) and infrastructure subscription (Private DNS Zone Contributor). If deployed manually, the permissions below should be sufficient.

  - **Infrastructure Subscription**
    - **Private DNS Zone Contributor**: Needed over the Private DNS Zones to create the required DNS records for the Private Endpoints
  - **Workload Subscription**
    - **Role Based Access Control Administrator**: Needed over the resource group to create relevant role assignments
    - **Network Contributor**: Needed over the resource group to create the Private Endpoints
    - **Azure AI Account Owner**: Needed to create a cognitive services account and project 
    - **Owner or Role Based Access Administrator**: Needed to assign RBAC to the required resources (Cosmos DB, Azure AI Search, Storage) 
    - **Azure AI User**: Needed to create and edit agents

2. **Register Resource Providers**

   Make sure you have an active Azure subscription for the workload that allows registering resource providers. For example, subnet delegation requires the Microsoft.App provider to be registered in your subscription. If it's not already registered, run the commands below:

   ```bash
   az provider register --namespace 'Microsoft.KeyVault'
   az provider register --namespace 'Microsoft.CognitiveServices'
   az provider register --namespace 'Microsoft.Storage'
   az provider register --namespace 'Microsoft.Search'
   az provider register --namespace 'Microsoft.Network'
   az provider register --namespace 'Microsoft.App'
   az provider register --namespace 'Microsoft.ContainerService'
   ```

3. Sufficient quota for all resources in your target Azure region

4. Azure CLI installed and configured on your local workstation or deployment pipeline server

5. Terraform CLI version v1.11.4 or later on your local workstation or depoyment pipeline server. This template requires the usage of both the AzureRm and AzApi Terraform providers.

## Pre-Deployment Steps

1. Create a virtual network of sufficient address space. The virtual network should be configured with proper DNS settings to ensure it can resolve the required Private DNS Zones.
  - **Agent Subnet** (e.g., 192.168.0.0/24): Hosts Agent client for Agent workloads 
  - **Private endpoint Subnet** (e.g. 192.168.1.0/24): Hosts private endpoints 
    - Ensure that the address spaces for these subnets do not overlap with any existing networks in your Azure environment or connected on-premises environments.

2. Validate that the subnet that will be delegated to the Agents service has been configured for delegation for Microsoft.App/environments. Without this delegation the deployment will fail.

3. Create the Private DNS Zones listed below. Ensure they are linked to the relevant virtual network which will depend on your DNS resolution pattern for Azure.

    - privatelink.cognitiveservices.azure.com
    - privatelink.openai.azure.com
    - privatelink.services.ai.azure.com
    - privatelink.blob.core.windows.net
    - privatelink.search.windows.net
    - privatelink.documents.azure.com
---

## Template Customization

This version allows the deployment to reuse existing:

- Azure Storage
- Azure Cosmos DB for NoSQL
- Azure AI Search

instead of always creating them. The template still creates the remaining Microsoft Foundry resources and standard-setup wiring needed for the project. Standard setup is explicitly documented as using customer-managed Storage, Search, and Cosmos DB resources for file storage, vector stores, and thread storage.

It also adds support for:
- passing full ARM IDs for existing resources
- conditionally skipping private endpoint creation for those reused resources when private endpoints already exist in the target VNet topology. The upstream 15b sample normally creates private endpoints for Storage, Cosmos DB, Azure AI Search, and Foundry.

---

## Files changed

**terraform.tfvars**
Adds deployment-time values for existing resource reuse:
- existing_storage_account_id
- existing_search_service_id
- existing_cosmos_account_id
- create_private_endpoints_for_existing_resources

Use these to point the template at existing Storage, Search, and Cosmos resources.

---

**variables.tf**
Adds the corresponding Terraform variables for:
- existing Storage ARM ID
- existing Search ARM ID
- existing Cosmos ARM ID
- PE creation toggle for reused resources

These inputs enable the template to switch between:
- creating new resources, or
- reusing existing ones.

---

**locals.tf**
Adds "effective resource" locals so downstream logic can work with either:
- resources created by Terraform, or
- resources passed in by ARM ID

Typical locals added:
- storage_account_id, search_service_id, cosmos_account_id
- storage_account_name, search_service_name, cosmos_account_name
- storage_blob_endpoint, cosmos_endpoint

This keeps connection, RBAC, and capability-host logic independent of whether resources are newly created or reused.

---

**data.tf**
Introduces lookups for existing resources where more than the ARM ID is needed.

Used to resolve values such as:
- Storage blob endpoint
- Cosmos DB endpoint

This is required because project connection resources need actual service endpoints, not just resource IDs.

---

**main.tf**
This is where most customization happens.

1. Conditional creation of parent resources
These resources are now created only when an existing ARM ID is not supplied:
- azurerm_storage_account.storage_account
- azurerm_cosmosdb_account.cosmosdb
- azapi_resource.ai_search

2. Conditional creation of private endpoints for reused resources
These PE resources now skip creation when:
- an existing ARM ID is provided, and
- create_private_endpoints_for_existing_resources = false

Applies to:
- azurerm_private_endpoint.pe_storage
- azurerm_private_endpoint.pe_cosmosdb
- azurerm_private_endpoint.pe_aisearch

The Foundry PE is still created because the Foundry resource itself is still provisioned by the template. The upstream sample explicitly includes a Foundry private endpoint and related private DNS zones.

3. Connections updated to use effective locals
Project connections to Storage, Search, and Cosmos now reference the effective locals instead of assuming those resources were created in the same template.

4. RBAC updated to support reused resources
Role assignments now scope to effective resource IDs/ names rather than directly to created resources.

5. Capability host updated to use reused connection names
The project capability host now references:
- storage_account_name
- search_service_name
- cosmos_account_name

This preserves standard-setup behavior with reused resources. The standard setup flow explicitly includes project connections and capability-host configuration for Cosmos DB, Azure Storage, and Azure AI Search.

6. Cosmos DB native data-plane RBAC expanded
A database-scope Cosmos native role assignment was added for the project identity after agent loading failed with missing `Microsoft.DocumentDB/databaseAccounts/readMetadata`. The Data plane security reference - Azure Cosmos DB doc explicitly says:

- readMetadata is required for SDK metadata access
- Cosmos DB Built-in Data Contributor includes readMetadata
- the permission can be assigned at the account, database, or container scope.

This was used to cover additional Foundry-created containers under enterprise_memory, such as *-agent-definitions-v1, etc..

---

### Variables

The variables listed below [must be provided](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence) when performing deploying the templates. The file example.tfvars provides a sample Terraform variables file that can be used.
- **resource_group_name_resources** - The name of the resource group where the resources created with this template will be depoyed to.
- **resource_group_name_dns** - This name of the resource group where the pre-existing Private DNS Zones have been deployed to.
- **subnet_id_agent** - The Azure resource ID of the subnet that will be delegated to the Agent service. This subnet must be delegated to Microsoft.App/environments prior to deployment of the resources.
- **subnet_id_private_endpoint** - This Azure resource id of the subnet where Private Endpoints created by this template will be deployed.
- **subscription_id_resources** - The subscription ID (ex: 55555555-5555-5555-5555-555555555555) that the resources created with this template will be deployed to.
- **subscription_id_infra** - The subscription ID (ex: 55555555-5555-5555-5555-555555555555) where the pre-existing Private DNS zones have been deployed to.
- **location** - The Azure region the resources will be deployed to. This must be the same region where the pre-existing virtual network has been deployed to.
- **existing_storage_account_id** - ARM ID of existing storage account service.
- **existing_search_service_id** - ARM ID of existing ai search service.
- **existing_cosmos_account_id** - ARM ID of existing cosmos db account service.
- **create_private_endpoints_for_existing_resources** - Flag to create PE for existing resources (usually, expected that existing resource will have PE, so it can be false; if new PE needed, set it true).

---

## Deploy the Terraform template

1. Fill in the required information for the variables listed in the `example.tfvars` file and rename the file to `terraform.tfvars`.

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

## Maintenance

### Regular Tasks

1. Review role assignments
2. Monitor network security
3. Check service health
4. Update configurations as needed

### Troubleshooting

1. Verify private endpoint connectivity
2. Check DNS resolution
3. Validate role assignments
4. Review network security groups

---

## References

- [Azure AI Foundry Networking Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link?tabs=azure-portal&pivots=fdp-project)
- [Azure AI Foundry RBAC Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/rbac-azure-ai-foundry?pivots=fdp-project)
- [Private Endpoint Documentation](https://learn.microsoft.com/en-us/azure/private-link/)
- [RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/)
- [Network Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)
