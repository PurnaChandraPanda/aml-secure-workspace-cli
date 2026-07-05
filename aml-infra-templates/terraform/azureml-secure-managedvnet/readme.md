# AzureML Secure Managed VNet - Terraform

This sample deploys an Azure Machine Learning workspace with public network access disabled, customer-managed private endpoints, private DNS, supporting platform services, and Azure ML managed network provisioning.

The Terraform configuration is kept in the [code](./code) folder. It is organized as a single Terraform deployment with clear internal sections instead of separate reusable Terraform modules.

## What this sample creates

- Azure Machine Learning workspace with system-assigned managed identity.
- AML managed network configured with `AllowOnlyApprovedOutbound` by default.
- Storage account, Key Vault, Azure Container Registry, Log Analytics, and Application Insights.
- Optional new VNet and private endpoint subnet, or reuse of existing network resources.
- Private DNS zones and VNet links, or reuse of existing Private DNS zones.
- Private endpoints for AML, Storage blob, Storage file, Key Vault, Container Registry, and Azure Monitor Private Link Scope.
- Azure Monitor Private Link Scope links for Log Analytics and Application Insights.
- Explicit AML managed network provisioning after workspace creation.

## Folder structure

| Path | Purpose |
| --- | --- |
| [code/main.tf](./code/main.tf) | Main deployment flow for network, DNS, platform resources, AML workspace, private endpoints, AMPLS, and managed network provisioning. |
| [code/variables.tf](./code/variables.tf) | Inputs for location, naming, network reuse, DNS reuse, AML managed network mode, AMPLS reuse, and tags. |
| [code/locals.tf](./code/locals.tf) | Derived resource names, resource group IDs, DNS zone names, selected VNet/subnet IDs, and role definition IDs. |
| [code/outputs.tf](./code/outputs.tf) | Useful deployment outputs such as workspace ID, private DNS zone IDs, VNet ID, subnet ID, and dependent service names. |
| [code/versions.tf](./code/versions.tf) | Terraform and provider requirements. This sample uses the AzAPI provider and random provider. |
| [post_deploy_script.sh](./post_deploy_script.sh) | Adds FQDN outbound rules and re-provisions the AML managed network after Terraform deployment. |

## Inner deployment sections

### 1. Network

The network section can either create a new VNet and private endpoint subnet or reuse existing resources.

Controlled by:

- `create_vnet`
- `existing_vnet_id`
- `create_private_endpoint_subnet`
- `existing_private_endpoint_subnet_id`
- `vnet_address_space`
- `private_endpoint_subnet_prefixes`

The private endpoint subnet is configured with private endpoint network policies disabled, which is required for private endpoint deployment.

### 2. Input validation

`terraform_data.network_input_validation` checks the network combinations before deployment. For example, if subnet creation is disabled, an existing private endpoint subnet ID must be provided. If DNS VNet links are enabled, Terraform must be able to resolve a VNet ID.

### 3. Private DNS

The private DNS section creates only the zones that are not supplied through `existing_private_dns_zone_ids`.

Supported DNS zone keys:

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

When `create_private_dns_zone_vnet_links` is true, the sample links the DNS zones to the selected VNet.

### 4. Platform resources

The platform resource section creates the services that the AzureML workspace depends on:

- Log Analytics workspace
- Application Insights component
- Storage account
- Key Vault
- Azure Container Registry

Storage, Key Vault, and Container Registry are configured with public network access disabled. ACR uses the `Premium` SKU because private endpoint support requires it.

### 5. AzureML workspace

The AzureML workspace is created with AzAPI using `Microsoft.MachineLearningServices/workspaces`. It references the platform resources created earlier and disables public network access.

Managed network settings are controlled by `aml_managed_network_isolation_mode`. The default is `AllowOnlyApprovedOutbound`, which means outbound access must be approved through AML managed network outbound rules.

### 6. Private endpoints

The private endpoint section creates customer-managed private endpoints in the selected private endpoint subnet for:

- AML workspace, using AML API and notebooks DNS zone groups.
- Storage blob.
- Storage file.
- Key Vault.
- Azure Container Registry.
- Azure Monitor Private Link Scope, when `create_ampls_private_endpoint` is true.

Each private endpoint also creates the matching private DNS zone group.

### 7. Azure Monitor Private Link Scope

The AMPLS section creates or reuses an Azure Monitor Private Link Scope. It links Log Analytics and Application Insights as scoped resources, then optionally creates a private endpoint for Azure Monitor traffic.

Controlled by:

- `existing_ampls_id`
- `create_ampls_private_endpoint`

### 8. AML managed network provisioning

The final Terraform action calls `provisionManagedNetwork` for the AML workspace. This asks the AzureML resource provider to provision the workspace managed network after the workspace exists.

FQDN outbound rules are handled in [post_deploy_script.sh](./post_deploy_script.sh).


## Key variables to review

| Variable | Why it matters |
| --- | --- |
| `location` | Azure region for the resources. |
| `prefix` | Short prefix used to generate resource names. |
| `network_resource_group_name` | Resource group for VNet, private endpoints, and Private DNS zones. |
| `resource_group_name` | Resource group for AML and platform resources. |
| `aml_managed_network_isolation_mode` | Controls AML managed VNet outbound mode. Defaults to `AllowOnlyApprovedOutbound`. |
| `existing_private_dns_zone_ids` | Reuses existing Private DNS zones instead of creating new ones. |
| `create_vnet` / `existing_vnet_id` | Chooses whether this sample creates or reuses the VNet. |
| `create_private_endpoint_subnet` / `existing_private_endpoint_subnet_id` | Chooses whether this sample creates or reuses the private endpoint subnet. |
| `existing_ampls_id` | Reuses an existing Azure Monitor Private Link Scope. |

## How to run it

From this sample folder:

```bash
cd code
```

Before running any command, make sure `terraform.tfvars` file is ready. The sample `tfvars` files are given as `example1.tfvars` or `example2.tfvars`.

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

If an apply fails partway through, fix the issue and rerun the same commands. Terraform will compare local state with deployed Azure resources and continue from the remaining changes when possible.

## Post-deployment outbound rules

After Terraform completes, update [post_deploy_script.sh](./post_deploy_script.sh) with the correct subscription ID, resource group, and workspace name, then run:

```bash
cd ..
./post_deploy_script.sh
```

The script currently adds FQDN outbound rules for:

- `pypi.org`
- `*.blob.core.windows.net`

It then lists the outbound rules and re-provisions the AML managed network.

## Useful outputs

After deployment, Terraform exposes outputs for:

- AML workspace name, ID, and principal ID.
- VNet and private endpoint subnet IDs.
- Private DNS zone IDs.
- Storage account name.
- Key Vault name.
- Container Registry name.
- Managed network isolation mode.

Use these outputs when updating the post-deployment script, validating private endpoint connectivity, or wiring follow-on workloads to the workspace.

