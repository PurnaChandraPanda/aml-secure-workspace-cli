# AzureML Secure BYO VNet - Bicep

This sample deploys an Azure Machine Learning workspace with public network access disabled and private endpoints in a customer-managed virtual network. It does not enable an Azure ML managed virtual network or deploy Azure Monitor Private Link Scope (AMPLS).

The deployment starts from [main.bicep](./main.bicep), which runs at subscription scope and orchestrates resource-group scoped modules under [modules](./modules). Use [main.bicepparam](./main.bicepparam) to provide environment-specific values.

## What this sample creates

- Azure Machine Learning workspace with system-assigned managed identity and public network access disabled.
- Optional new VNet and private endpoint subnet, or reuse of existing network resources.
- Storage account, Key Vault, Azure Container Registry, Log Analytics, and Application Insights.
- Private DNS zones and VNet links, or reuse of existing Private DNS zones.
- Private endpoints for AML, Storage blob, Storage file, Key Vault, and Container Registry.
- Deployment outputs for the workspace, platform services, VNet, and private endpoint subnet.

## Network model

This sample uses a customer-managed VNet for private endpoints. It does not configure the Azure ML workspace `managedNetwork` property or provision managed-network outbound rules.

The private endpoints provide private access to the workspace and its dependent services. Compute resources are not deployed by this sample. Configure VNet injection, routing, network security groups, DNS, and required outbound access separately for any compute instance, compute cluster, or Kubernetes target that you add.

## Folder structure

| Path | Purpose |
| --- | --- |
| [main.bicep](./main.bicep) | Subscription-scope orchestration file that wires all modules together and emits useful outputs. |
| [main.bicepparam](./main.bicepparam) | Example parameter file. Update subscription-specific resource group, VNet, DNS, and tag values before deployment. |
| [modules/network.bicep](./modules/network.bicep) | Creates or reuses the VNet and private endpoint subnet. |
| [modules/private-dns.bicep](./modules/private-dns.bicep) | Creates missing Private DNS zones and optional VNet links, or reuses existing zone IDs. |
| [modules/monitor.bicep](./modules/monitor.bicep) | Creates Log Analytics and Application Insights. |
| [modules/platform-resources.bicep](./modules/platform-resources.bicep) | Creates private Storage, Key Vault, and Container Registry resources. |
| [modules/aml-workspace.bicep](./modules/aml-workspace.bicep) | Creates the Azure ML workspace with public network access disabled. |
| [modules/private-endpoint.bicep](./modules/private-endpoint.bicep) | Reusable private endpoint and private DNS zone group module. |

## Deployment flow

### 1. Subscription-scope orchestration

[main.bicep](./main.bicep) uses `targetScope = 'subscription'` and deploys:

- Network resources to `networkResourceGroupName`.
- The Azure ML workspace and platform resources to `platformResourceGroupName`.

Both resource groups must already exist.

### 2. Network module

[modules/network.bicep](./modules/network.bicep) can create a new VNet and private endpoint subnet or reuse existing resource IDs.

Key parameters:

- `createVnet`
- `existingVnetId`
- `createPrivateEndpointSubnet`
- `existingPrivateEndpointSubnetId`
- `vnetAddressPrefixes`
- `privateEndpointSubnetPrefixes`

When the subnet is created by this sample, private endpoint network policies are disabled.

### 3. Private DNS module

[modules/private-dns.bicep](./modules/private-dns.bicep) creates only the Private DNS zones that are not passed through `existingPrivateDnsZoneIds`.

Supported DNS zone keys:

- `aml_api`
- `aml_notebooks`
- `storage_blob`
- `storage_file`
- `key_vault`
- `acr`

Set `createPrivateDnsZoneVnetLinks = false` when DNS VNet links already exist or are managed outside this deployment.

### 4. Monitoring module

[modules/monitor.bicep](./modules/monitor.bicep) creates a Log Analytics workspace and an Application Insights component connected to it. Monitoring uses its configured public ingestion and query endpoints; this sample does not deploy AMPLS.

### 5. Platform resources module

[modules/platform-resources.bicep](./modules/platform-resources.bicep) creates:

- Storage account
- Key Vault
- Azure Container Registry

These resources have public network access disabled. ACR uses the `Premium` SKU because private endpoint support requires it.

### 6. Azure ML workspace module

[modules/aml-workspace.bicep](./modules/aml-workspace.bicep) creates the workspace with:

- System-assigned managed identity.
- Public network access disabled.
- References to Application Insights, Storage, Key Vault, and ACR.

The workspace does not enable an Azure ML managed VNet.

### 7. Private endpoint module

[modules/private-endpoint.bicep](./modules/private-endpoint.bicep) is reused for all private endpoints. Each call creates:

- A private endpoint.
- A private service connection to the target resource.
- A `default` private DNS zone group.

The module is used for:

- AML workspace with the `amlworkspace` group ID.
- Storage blob with the `blob` group ID.
- Storage file with the `file` group ID.
- Key Vault with the `vault` group ID.
- Container Registry with the `registry` group ID.

## Key parameters to review

| Parameter | Why it matters |
| --- | --- |
| `location` | Azure region for regional resources. |
| `prefix` | Short lowercase prefix used to generate resource names. |
| `networkResourceGroupName` | Resource group for the VNet, private endpoints, and Private DNS zones. |
| `platformResourceGroupName` | Resource group for the AML workspace and dependent platform resources. |
| `createVnet` / `existingVnetId` | Chooses whether Bicep creates or reuses the VNet. |
| `createPrivateEndpointSubnet` / `existingPrivateEndpointSubnetId` | Chooses whether Bicep creates or reuses the private endpoint subnet. |
| `existingPrivateDnsZoneIds` | Reuses existing Private DNS zones instead of creating new ones. |
| `createPrivateDnsZoneVnetLinks` | Controls whether this deployment creates DNS VNet links. |

## How to run it

Sign in to Azure and select the target subscription:

```bash
az login --tenant <tenant-id>
az account set --subscription <subscription-id>
```

Update [main.bicepparam](./main.bicepparam) with the target values, then validate:

```bash
az deployment sub validate \
  --location eastus2 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Preview the changes:

```bash
az deployment sub what-if \
  --location eastus2 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Deploy:

```bash
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Outputs

The deployment returns:

- `amlWorkspaceName`
- `amlWorkspaceId`
- `storageAccountName`
- `keyVaultName`
- `acrName`
- `vnetId`
- `privateEndpointSubnetId`

Use these outputs when validating the deployment and configuring customer-managed compute networking.
