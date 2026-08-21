# AzureML Secure BYO VNet - Terraform

This sample deploys an Azure Machine Learning workspace with public network access disabled and private endpoints in a customer-managed virtual network. It does not enable an Azure ML managed virtual network or deploy Azure Monitor Private Link Scope (AMPLS).

The Terraform configuration is in the [code](./code) folder and is organized as a single deployment with clear internal sections.

## What this sample creates

- Azure Machine Learning workspace with system-assigned managed identity and public network access disabled.
- Optional new VNet and private endpoint subnet, or reuse of existing network resources.
- Storage account, Key Vault, Azure Container Registry, Log Analytics, and Application Insights.
- Private DNS zones and VNet links, or reuse of existing Private DNS zones.
- Private endpoints for AML, Storage blob, Storage file, Key Vault, and Container Registry.
- Outputs for the workspace, platform services, VNet, private endpoint subnet, and Private DNS zones.

## Network model

This sample uses a customer-managed VNet for private endpoints. It does not configure the Azure ML workspace `managedNetwork` property or provision managed-network outbound rules.

The private endpoints provide private access to the workspace and its dependent services. Compute resources are not deployed by this sample. Configure VNet injection, routing, network security groups, DNS, and required outbound access separately for any compute instance, compute cluster, or Kubernetes target that you add.

## Folder structure

| Path | Purpose |
| --- | --- |
| [code/main.tf](./code/main.tf) | Deploys the network, DNS, platform resources, AML workspace, and private endpoints. |
| [code/variables.tf](./code/variables.tf) | Defines location, naming, network reuse, DNS reuse, and tag inputs. |
| [code/locals.tf](./code/locals.tf) | Defines resource names, resource group IDs, DNS zone names, selected VNet/subnet IDs, and role definition IDs. |
| [code/outputs.tf](./code/outputs.tf) | Exposes workspace, DNS, VNet, subnet, and dependent service values. |
| [code/versions.tf](./code/versions.tf) | Defines Terraform and provider requirements. |
| [code/example1.tfvars](./code/example1.tfvars) | Example that creates the VNet, subnet, and DNS resources. |
| [code/example2.tfvars](./code/example2.tfvars) | Example that reuses existing network and DNS resources. |

## Deployment sections

### 1. Network

The network section can create a VNet and private endpoint subnet or reuse existing resources.

Controlled by:

- `create_vnet`
- `existing_vnet_id`
- `create_private_endpoint_subnet`
- `existing_private_endpoint_subnet_id`
- `vnet_address_space`
- `private_endpoint_subnet_prefixes`

When Terraform creates the subnet, private endpoint network policies are disabled.

### 2. Input validation

`terraform_data.network_input_validation` validates network input combinations before deployment. For example, an existing private endpoint subnet ID is required when subnet creation is disabled.

### 3. Private DNS

Terraform creates only the Private DNS zones that are not supplied through `existing_private_dns_zone_ids`.

Supported DNS zone keys:

- `aml_api`
- `aml_notebooks`
- `storage_blob`
- `storage_file`
- `key_vault`
- `acr`

When `create_private_dns_zone_vnet_links` is true, Terraform links these zones to the selected VNet.

### 4. Platform resources

The platform resource section creates:

- Log Analytics workspace
- Application Insights component
- Storage account
- Key Vault
- Azure Container Registry

Storage, Key Vault, and Container Registry have public network access disabled. ACR uses the `Premium` SKU because private endpoint support requires it.

Application Insights uses its configured public ingestion and query endpoints; this sample does not deploy AMPLS.

### 5. Azure ML workspace

The workspace is created with AzAPI using `Microsoft.MachineLearningServices/workspaces`. It references the platform resources, uses a system-assigned managed identity, and disables public network access.

The workspace does not enable an Azure ML managed VNet.

### 6. Private endpoints

Terraform creates customer-managed private endpoints in the selected subnet for:

- AML workspace, using AML API and notebooks DNS zones.
- Storage blob.
- Storage file.
- Key Vault.
- Azure Container Registry.

Each private endpoint has a matching private DNS zone group.

## Key variables to review

| Variable | Why it matters |
| --- | --- |
| `location` | Azure region for the resources. |
| `prefix` | Short prefix used to generate resource names. |
| `network_resource_group_name` | Resource group for the VNet, private endpoints, and Private DNS zones. |
| `resource_group_name` | Resource group for AML and platform resources. |
| `create_vnet` / `existing_vnet_id` | Chooses whether Terraform creates or reuses the VNet. |
| `create_private_endpoint_subnet` / `existing_private_endpoint_subnet_id` | Chooses whether Terraform creates or reuses the private endpoint subnet. |
| `existing_private_dns_zone_ids` | Reuses existing Private DNS zones instead of creating new ones. |
| `create_private_dns_zone_vnet_links` | Controls whether Terraform creates DNS VNet links. |

## How to run it

From this sample folder:

```bash
cd code
```

Copy the appropriate example to `terraform.tfvars` and update its values:

```bash
cp example1.tfvars terraform.tfvars
```

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

If an apply fails partway through, fix the issue and rerun the same commands. Terraform compares its state with deployed Azure resources and continues from the remaining changes.

## Useful outputs

After deployment, Terraform exposes:

- AML workspace name, ID, and principal ID.
- VNet and private endpoint subnet IDs.
- Private DNS zone IDs.
- Storage account name.
- Key Vault name.
- Container Registry name.

Use these outputs to validate private endpoint connectivity or configure follow-on workloads.
