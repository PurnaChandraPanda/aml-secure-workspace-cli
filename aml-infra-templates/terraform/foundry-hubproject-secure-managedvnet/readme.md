# Azure AI Foundry Hub and Project - Secure Managed VNet Terraform

This sample deploys a secure Azure AI Foundry hub and project using Terraform with the AzAPI provider. The hub is created as a `Microsoft.MachineLearningServices/workspaces` resource with `kind = "Hub"`, and the project is created as a related workspace with `kind = "Project"`.

The sample focuses on a private-networked Foundry setup: public access is disabled, shared platform services are private, private endpoints are created in a customer-managed VNet, and the hub managed network is provisioned with approved outbound access.

## What this sample creates

- Azure AI Foundry hub with system-assigned managed identity.
- Azure AI Foundry project linked to the hub through `hubResourceId`.
- Storage account, Key Vault, Azure Container Registry, Log Analytics, and Application Insights.
- New or existing VNet support for private endpoint placement.
- New or existing Private DNS zone support.
- Private endpoints for the Foundry hub, Storage blob, Storage file, Key Vault, Container Registry, and Azure Monitor Private Link Scope.
- Azure Monitor Private Link Scope links for Log Analytics and Application Insights.
- Hub managed network provisioning through the Azure Machine Learning resource provider.
- Post-deployment FQDN outbound rules for the hub managed network.

## Folder structure

| Path | Purpose |
| --- | --- |
| [code/main.tf](./code/main.tf) | Main deployment flow for networking, DNS, platform resources, Foundry hub/project, private endpoints, AMPLS, and managed network provisioning. |
| [code/variables.tf](./code/variables.tf) | Input variables for location, naming, network reuse, DNS reuse, managed network mode, AMPLS reuse, and tags. |
| [code/locals.tf](./code/locals.tf) | Derived names, resource group IDs, Private DNS zone names, selected VNet/subnet IDs, and shared role definition IDs. |
| [code/terraform.tfvars](./code/terraform.tfvars) | Example values for deploying into an existing VNet, existing Private DNS zones, and existing AMPLS. Update these values before running. |
| [code/versions.tf](./code/versions.tf) | Terraform and provider requirements. This sample uses `Azure/azapi` and `hashicorp/random`. |
| [post_deploy_script.sh](./post_deploy_script.sh) | Adds FQDN outbound rules to the Foundry hub and re-provisions the managed network. |

## Deployment flow

### 1. Network selection

The sample can create a new VNet and private endpoint subnet, or it can reuse existing network resources.

Key variables:

- `create_vnet`
- `existing_vnet_id`
- `create_private_endpoint_subnet`
- `existing_private_endpoint_subnet_id`
- `vnet_address_space`
- `private_endpoint_subnet_prefixes`

The private endpoint subnet is configured with private endpoint network policies disabled when Terraform creates it.

### 2. Network input validation

`terraform_data.network_input_validation` validates supported combinations before resources are created. For example, when Terraform does not create the private endpoint subnet, `existing_private_endpoint_subnet_id` must be supplied.

### 3. Private DNS

The configuration creates missing Private DNS zones and can link them to the selected VNet. If a zone ID is supplied through `existing_private_dns_zone_ids`, Terraform reuses that zone instead of creating it.

Supported Private DNS zone keys:

- `aml_api`
- `aml_notebooks`
- `storage_blob`
- `storage_file`
- `key_vault`
- `acr`
- `monitor`
- `oms`
- `ods`
- `agentsvc`

Set `create_private_dns_zone_vnet_links = false` when the zone links already exist or are managed elsewhere.

### 4. Platform resources

The platform section creates the shared services required by the Foundry hub:

- Log Analytics workspace
- Application Insights component
- Storage account
- Key Vault
- Azure Container Registry

Storage, Key Vault, and Container Registry are deployed with public network access disabled. ACR is restricted to the `Premium` SKU because private endpoint support requires Premium.

### 5. Foundry hub

The hub is deployed through AzAPI as a Machine Learning workspace with `kind = "Hub"`. It references the platform resources, disables public network access, enables managed network provisioning, and sets the managed network isolation mode from `aml_managed_network_isolation_mode`.

The default managed network mode is `AllowOnlyApprovedOutbound`, which means outbound access should be explicitly approved through managed network outbound rules.

### 6. Foundry project

The project is deployed as a Machine Learning workspace with `kind = "Project"`. The important relationship is `hubResourceId`, which attaches the project to the hub created earlier.

The project also has public network access disabled. It generally inherits the hub's networking and governance behavior.

### 7. Private endpoints

The private endpoint section creates private access paths for:

- Foundry hub, using the `amlworkspace` private link group and AML API/notebooks DNS zones.
- Storage blob.
- Storage file.
- Key Vault.
- Azure Container Registry.
- Azure Monitor Private Link Scope, when enabled.

Each private endpoint creates the matching private DNS zone group.

### 8. Azure Monitor Private Link Scope

The AMPLS section creates or reuses an Azure Monitor Private Link Scope. It links Log Analytics and Application Insights as scoped resources, then optionally creates an AMPLS private endpoint.

Key variables:

- `existing_ampls_id`
- `create_ampls_private_endpoint`

### 9. Managed network provisioning

Terraform calls the `provisionManagedNetwork` action on the Foundry hub after the hub is created. This asks the Azure Machine Learning resource provider to provision the hub managed network.

FQDN outbound rules are added by [post_deploy_script.sh](./post_deploy_script.sh), not by active Terraform resources. 

## Key variables to review

| Variable | Why it matters |
| --- | --- |
| `location` | Azure region for resources. |
| `prefix` | Short lowercase prefix used to generate names for the hub, project, and supporting services. |
| `network_resource_group_name` | Resource group that contains or receives VNet, private endpoints, and Private DNS zones. |
| `resource_group_name` | Resource group that contains the Foundry hub, project, and platform resources. |
| `aml_managed_network_isolation_mode` | Controls managed network outbound behavior. Defaults to `AllowOnlyApprovedOutbound`. |
| `create_vnet` / `existing_vnet_id` | Chooses whether Terraform creates or reuses the VNet. |
| `create_private_endpoint_subnet` / `existing_private_endpoint_subnet_id` | Chooses whether Terraform creates or reuses the private endpoint subnet. |
| `existing_private_dns_zone_ids` | Reuses existing Private DNS zones instead of creating new zones. |
| `create_private_dns_zone_vnet_links` | Controls whether Terraform creates VNet links for DNS zones. |
| `existing_ampls_id` | Reuses an existing Azure Monitor Private Link Scope. |
| `create_ampls_private_endpoint` | Controls whether Terraform creates a private endpoint for AMPLS. |

## How to run it

From this sample folder:

```bash
cd code
```

Before running any command, make sure `terraform.tfvars` file is ready. The sample `tfvars` files are given as `example1.tfvars` or `example2.tfvars`. Update for your subscription, resource groups, networking, DNS zones, AMPLS choice, and tags.

Sign in to Azure:

```bash
az login
```

Or sign in with a specific tenant:

```bash
az login --tenant <tenant-id>
```

Initialize Terraform:

```bash
terraform init
```

Format, validate, plan, and apply:

```bash
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

If an apply fails partway through, fix the issue and rerun the same commands. Terraform will compare state with Azure and continue from the remaining changes when possible.

## Post-deployment outbound rules

After Terraform completes, update [post_deploy_script.sh](./post_deploy_script.sh) with the correct subscription ID, resource group, and Foundry hub name, then run:

```bash
cd ..
./post_deploy_script.sh
```

The script currently adds managed network FQDN outbound rules for:

- `pypi.org`
- `*.blob.core.windows.net`

It then lists the outbound rules and re-provisions the hub managed network.

## Notes

- The sample does not currently define a separate `outputs.tf`. Use the generated names in `locals.tf`, Terraform state, Azure portal, or Azure CLI queries to retrieve deployed resource names and IDs.
- The current [code/terraform.tfvars](./code/terraform.tfvars) demonstrates reuse of an existing VNet, existing private endpoint subnet, existing Private DNS zones, and existing AMPLS.
- The Foundry hub and project are deployed through the Machine Learning workspace resource provider because Azure AI Foundry hub/project resources are represented through that API surface.

## Reference

- [Microsoft.MachineLearningServices workspaces Terraform API](https://learn.microsoft.com/en-us/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-terraform#terraform-azapi-provider-resource-definition)