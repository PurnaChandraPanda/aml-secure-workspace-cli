# Azure AI Foundry Hub and Project - Secure Managed VNet Bicep

This sample deploys an Azure AI Foundry hub and project with private networking, supporting platform resources, Private DNS, private endpoints, Azure Monitor Private Link Scope, and managed network provisioning.

The deployment starts from [main.bicep](./main.bicep), which runs at subscription scope and orchestrates resource-group scoped modules under [modules](./modules). Use [main.bicepparam](./main.bicepparam) to provide environment-specific values.

## What this sample creates

- Azure AI Foundry hub with system-assigned managed identity.
- Azure AI Foundry project linked to the hub through `hubResourceId`.
- Storage account, Key Vault, Azure Container Registry, Log Analytics, and Application Insights.
- Optional new VNet and private endpoint subnet, or reuse of existing network resources.
- Private DNS zones and optional VNet links, or reuse of existing Private DNS zones.
- Private endpoints for the Foundry hub, Storage blob, Storage file, Key Vault, Container Registry, and optionally Azure Monitor Private Link Scope.
- Azure Monitor Private Link Scope scoped resources for Log Analytics and Application Insights.
- Deployment outputs for hub, project, platform services, VNet, and private endpoint subnet values.

## Folder structure

| Path | Purpose |
| --- | --- |
| [main.bicep](./main.bicep) | Subscription-scope orchestration file that wires all modules together and emits useful outputs. |
| [main.bicepparam](./main.bicepparam) | Example parameter file for resource groups, existing network, existing DNS zones, AMPLS, and tags. |
| [modules/network.bicep](./modules/network.bicep) | Creates or reuses the VNet and private endpoint subnet. |
| [modules/private-dns.bicep](./modules/private-dns.bicep) | Creates missing Private DNS zones and optional VNet links, or reuses existing zone IDs. |
| [modules/monitor.bicep](./modules/monitor.bicep) | Creates Log Analytics and Application Insights. |
| [modules/platform-resources.bicep](./modules/platform-resources.bicep) | Creates private Storage, Key Vault, and Container Registry resources. |
| [modules/foundry-hub-project.bicep](./modules/foundry-hub-project.bicep) | Creates the Foundry hub and project workspaces and configures hub managed network settings. |
| [modules/private-endpoint.bicep](./modules/private-endpoint.bicep) | Reusable private endpoint and private DNS zone group module. |
| [modules/ampls.bicep](./modules/ampls.bicep) | Creates or reuses Azure Monitor Private Link Scope. |
| [modules/ampls-scoped-resources.bicep](./modules/ampls-scoped-resources.bicep) | Links Log Analytics and Application Insights into AMPLS. |
| [post_deploy_script.sh](./post_deploy_script.sh) | Adds Foundry hub managed network FQDN outbound rules and re-provisions the managed network. |

## Deployment flow

### 1. Subscription-scope orchestration

[main.bicep](./main.bicep) uses `targetScope = 'subscription'` so modules can deploy into multiple resource groups:

- Network resources go to `networkResourceGroupName`.
- Foundry hub, project, and platform resources go to `platformResourceGroupName`.
- AMPLS resources go to `amplsResourceGroupName`.

The resource groups are expected to already exist.

### 2. Network module

[modules/network.bicep](./modules/network.bicep) can create a new VNet and private endpoint subnet, or reuse existing IDs from [main.bicepparam](./main.bicepparam).

Key parameters:

- `createVnet`
- `existingVnetId`
- `createPrivateEndpointSubnet`
- `existingPrivateEndpointSubnetId`
- `vnetAddressPrefixes`
- `privateEndpointSubnetPrefixes`

When the subnet is created by this sample, private endpoint network policies are disabled.

### 3. Private DNS module

[modules/private-dns.bicep](./modules/private-dns.bicep) creates only the Private DNS zones that are not passed in through `existingPrivateDnsZoneIds`.

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

Set `createPrivateDnsZoneVnetLinks = false` when DNS VNet links already exist or are managed outside this deployment.

### 4. Monitoring module

[modules/monitor.bicep](./modules/monitor.bicep) creates:

- Log Analytics workspace
- Application Insights component connected to Log Analytics

These resources are later linked to Azure Monitor Private Link Scope.

### 5. Platform resources module

[modules/platform-resources.bicep](./modules/platform-resources.bicep) creates the dependent services used by the Foundry hub:

- Storage account
- Key Vault
- Azure Container Registry

These resources are configured with public network access disabled. ACR uses `Premium` because private endpoint support requires it.

### 6. Foundry hub and project module

[modules/foundry-hub-project.bicep](./modules/foundry-hub-project.bicep) creates two `Microsoft.MachineLearningServices/workspaces` resources:

- Hub workspace with `kind: 'Hub'`.
- Project workspace with `kind: 'Project'`.

The project is attached to the hub through `hubResourceId`. The hub references the platform services, disables public network access, sets `provisionNetworkNow = true`, and configures the managed network mode from `foundryManagedNetworkIsolationMode`.

The default managed network mode is `AllowOnlyApprovedOutbound`, which means outbound access should be explicitly approved.

### 7. Private endpoint module

[modules/private-endpoint.bicep](./modules/private-endpoint.bicep) is reused for all private endpoints. Each call creates:

- A private endpoint.
- A private service connection to the target resource.
- A `default` private DNS zone group.

This sample uses it for:

- Foundry hub with `amlworkspace` group ID.
- Storage blob with `blob` group ID.
- Storage file with `file` group ID.
- Key Vault with `vault` group ID.
- Container Registry with `registry` group ID.
- AMPLS with `azuremonitor` group ID when `createAmplsPrivateEndpoint` is true.

### 8. AMPLS modules

[modules/ampls.bicep](./modules/ampls.bicep) creates a new Azure Monitor Private Link Scope or reuses `existingAmplsId`.

[modules/ampls-scoped-resources.bicep](./modules/ampls-scoped-resources.bicep) links Log Analytics and Application Insights into that AMPLS instance.

Use `createAmplsPrivateEndpoint = false` when the selected VNet already has an AMPLS private endpoint.

## Key parameters to review

| Parameter | Why it matters |
| --- | --- |
| `location` | Azure region for regional resources. |
| `prefix` | Short lowercase prefix used to generate hub, project, and supporting resource names. |
| `networkResourceGroupName` | Resource group for VNet, private endpoints, and Private DNS zones. |
| `platformResourceGroupName` | Resource group for Foundry hub, project, and dependent platform resources. |
| `foundryManagedNetworkIsolationMode` | Controls hub managed network outbound mode. Defaults to `AllowOnlyApprovedOutbound`. |
| `createVnet` / `existingVnetId` | Chooses whether Bicep creates or reuses the VNet. |
| `createPrivateEndpointSubnet` / `existingPrivateEndpointSubnetId` | Chooses whether Bicep creates or reuses the private endpoint subnet. |
| `existingPrivateDnsZoneIds` | Reuses existing Private DNS zones instead of creating new ones. |
| `createPrivateDnsZoneVnetLinks` | Controls whether this deployment creates DNS VNet links. |
| `existingAmplsId` | Reuses an existing Azure Monitor Private Link Scope. |
| `createAmplsPrivateEndpoint` | Controls whether this deployment creates an AMPLS private endpoint. |

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

## Post-deployment outbound rules

After deployment, update [post_deploy_script.sh](./post_deploy_script.sh) with the correct subscription ID, resource group, and Foundry hub name, then run:

```bash
./post_deploy_script.sh
```

The script currently adds managed network FQDN outbound rules for:

- `pypi.org`
- `*.blob.core.windows.net`

It then lists the outbound rules and re-provisions the hub managed network.

## Outputs

The deployment returns:

- `aiHubName`
- `aiHubId`
- `aiHubPrincipalId`
- `aiProjectName`
- `aiProjectId`
- `aiProjectPrincipalId`
- `storageAccountName`
- `keyVaultName`
- `acrName`
- `vnetId`
- `privateEndpointSubnetId`

Use these outputs when validating the deployment, updating the post-deployment script, or wiring follow-on workloads to the Foundry project.
