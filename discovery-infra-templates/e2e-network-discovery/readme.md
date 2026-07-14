## e2e network hardening

- For workspace data-plane private access, create/use a customer-owned VNet in your own RG and place the workspace private endpoint there. 
- The E2E hardened doc's model is one customer VNet with dedicated subnets like agent-ws, workspace-ws, pe-ws, bs-search, sc-aks, sc-nodepool, and pe-storage. 
- The pe-ws is explicitly for workspace/bookshelf private endpoints.

```
tree.com //F .
```

```
\e2e-network-discovery
│   main.bicep
│   main_1.bicepparam
│   main_1centraldnszone.bicepparam
│   main_2.bicepparam
│   main_3.bicepparam
│   project.bicep
│   project.bicepparam
│   readme.md
│   
├───modules
│       base.bicep
│       dns-links.bicep
│       network-existing-vnet-create-subnets.bicep
│       network-existing.bicep
│       network.bicep
│       private-endpoints.bicep
│       workspace-bootstrap.bicep
│
└───scripts
        deploy_1.sh
        deploy_1centraldnszone.sh
        deploy_2.sh
        deploy_3.sh
        deploy_project.sh
        post_discovery_setup.sh
        set_discovery_roles.sh  
```

## Why staged deployment?

This template uses staged deployment because the workspace is created with `publicNetworkAccess = Disabled` from the beginning.

- Stage 1 creates the network, secure workspace, private endpoints, and DNS integration.
- Stage 2 validates that the client can reach the workspace data-plane endpoint through VPN/private endpoint.
- Stage 3 creates Discovery project-level resources only after private access is confirmed.

This avoids attempting project or agent-related operations before the private data-plane path is reachable.

- Staged deployment
    - Stage 1 — Bicep: infrastructure and secure workspace only
    - Stage 2 — Shell: bring up VPN and validate private workspace access
    - Stage 3 — Create project only after private path is active

```
Stage 1:
  Network
  UAMI
  Azure Storage Account
  Blob container
  Supercomputer
  Nodepool
  Workspace with PNA Disabled
  Workspace Private Endpoint
  Storage Private Endpoint
  DNS zone groups

Stage 2:
  VPN Gateway + VPN client connectivity
  DNS and TCP 443 validation

Stage 3:
  Discovery storage container
  Chat model deployment
  Discovery project
```

```
subscription deployment: main.bicep
│
├── create network RG
├── create discovery RG
│
├── modules/network*.bicep
│   ├── VNet mode selection
│   ├── dedicated child subnets
│   ├── optional local DNS zones
│   └── optional VNet links
│
├── modules/base.bicep
│   ├── UAMI
│   ├── storage with PNA disabled
│   ├── supercomputer
│   └── node pool
│
├── modules/workspace-bootstrap.bicep
│   └── workspace with publicNetworkAccess = Disabled
│
├── modules/private-endpoints.bicep
│   ├── workspace private endpoint
│   ├── workspace DNS zone group
│   ├── storage private endpoint
│   └── storage DNS zone group
│
├── optional modules/dns-links.bicep
│   └── VNet links to central DNS zones
│
└── modules/project.bicep
    ├── chat model deployment
    ├── Discovery storage container
    └── Discovery project
```

```
resource group deployment: project.bicep 
│ 
├── Discovery storage container 
├── chat model deployment 
└── Discovery project
```


- on network mode:
```
create
  -> modules/network.bicep
  -> creates VNet + fresh child subnets + optional DNS zones

existing
  -> modules/network-existing.bicep
  -> does not create/update VNet/subnets
  -> only accepts existing subnet IDs and DNS zone IDs

existingVnetCreateSubnets
  -> modules/network-existing-vnet-create-subnets.bicep
  -> existing VNet
  -> creates fresh child subnets for this Discovery workspace
```

## Known gotchas

### Do not rerun full `main.bicep` for Stage 3

Stage 3 should use `project.bicep` only. Re-running the full `main.bicep` after VPN gateway creation can cause network/subnet operations to run again.

### Do not define subnets inline under the VNet

Use child subnet resources. This avoids accidental deletion or update attempts against unrelated subnets like `GatewaySubnet`.

### `createPrivateDnsVnetLinks` is only for existing DNS zones

If `network.bicep` creates DNS zones locally, keep `createPrivateDnsVnetLinks = false`.

### `existingVnetCreateSubnets` is the preferred future model

Use this mode when reusing the same customer VNet for multiple Discovery workspaces. Each workspace should get a fresh, non-overlapping subnet slice.

## Recommended production pattern

For repeatable enterprise deployments, use:

- `networkMode = existingVnetCreateSubnets`
- Existing shared customer VNet
- Fresh subnet slice per Discovery workspace
- Existing central or network-RG Private DNS zones
- Workspace and storage private endpoints in the Discovery RG
- Stage 3 project creation through `project.bicep` only

This keeps shared network infrastructure stable while allowing multiple Discovery workspaces to be deployed into the same VNet safely.

## how to deploy
For command line deployment, using the scripts in the root of this repo.

```
az login --tenant <tenant-id>
```

- update the parameters correctly and then run it (this step is one time to be carried out in subscription level)
```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

./scripts/set_discovery_roles.sh
```

- Additional RP to be registered in subscription level: `Microsoft.Network/AllowPrivateEndpoints`. Run it one time at subscription level. 
```
az feature register \
    --namespace Microsoft.Network \
    --name AllowPrivateEndpoints

// This is one time activity for customers following Discovery use cases in their subscription.
// It will show in pending for long. Open support request with Discovery product team to get the approval (this is a short term approach until rollouts are completed on NRP side).
// Then, it will show as registered.

az provider show \
  --namespace Microsoft.Network \
  --query "{namespace:namespace, registrationState:registrationState}" \
  -o table

az feature show \
    --namespace Microsoft.Network \
    --name AllowPrivateEndpoints \
    --query "{name:name, state:properties.state}" \
    -o table
```

- deploy discovery bicep template (stage 1): pick the options to follow (as per internal network governance)

```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

# Deploy the bicep template: stage 1 
## option 1: create vnet + create dns zone/ vnet link
- update parameters in deply_1.sh and main_1.bicepparam files
- deploy with the bicep template

./scripts/deploy_1.sh

## option 2: create vnet + link central dns zone
- update parameters in deploy_1centraldnszone.sh and main_1centraldnszone.bicepparam files
- deploy with the bicep template

./scripts/deploy_1centraldnszone.sh

## option 3: existing Vnet, create Subnets + link central dns zone
- update parameters in deply_2.sh and main_2.bicepparam files
- deploy with the bicep template

./scripts/deploy_2.sh

## option 4: existing Vnet, Subnets + link central dns zone
- update parameters in deply_3.sh and main_3.bicepparam files
- deploy with the bicep template

./scripts/deploy_3.sh
```

- In stage 2, get [vpn setup](../../vpn-gateway/readme.md) ready with vpn gateway service installed and then vpn client configured as well. 
    - As this is local DNS, update local hosts file with PE FQDN entries.
    - If its onprem DNS involved, then make sure either conditional forwarder or A records are kept on custom dns servers.
- Validate basic conncectivity to PE resource - of discovery and storage (kept in discovery RG).

```
ping yourdiscoveryname.workspace.discovery.azure.com
curl -v https://yourdiscoveryname.workspace.discovery.azure.com/
```

- deploy discovery bicep template (stage 3)
```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

# Deploy the bicep template: stage 3
- update parameters in deply_project.sh and project.bicepparam files
- deploy with the bicep template

./scripts/deploy_project.sh
```

- validate deployment
```
az resource list --resource-group rg-uks7discovery -o table
```

**Note** – The Supercomputer and Workspace resources can each take 30-120 minutes to provision.


- update parameters for post deploy script once discovery setup is ready
    - before you run it, make sure PE connectivity is fine
    - it assigns admin role at workspace RG level

```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1

# Add the `Platform Administrator` or `Scientist` persona
./scripts/post_discovery_setup.sh
```

## Access studio
- Make sure the VPN is connected or private workspace host is resolving to expected private IP.
- Launch the discovery studio - https://studio.discovery.microsoft.com/.
- Confirm you login with same userid and tenant scope as project is kept in.
- Projects -> Launch your respective project.
- VS Code window will open for the project.
- Click "new shared session".
- UI option will be there with default [Discovery] agent. If you want, you can create your own agent too.
- On default one, follow regular chat interaction.

- For logs, hit [ctrl+shift+p] for command pallete. Type "Devloper: Show logs". Pick [Discovery Studio]. Then, you can view all data plane operations are happening in agent scope from discovery service layer.


## reference

- [e2e discovery network hardened](https://learn.microsoft.com/en-us/azure/microsoft-discovery/how-to-deploy-network-hardened-stack)
- [Microsoft Discovery FAQ](https://learn.microsoft.com/en-us/azure/microsoft-discovery/faq)
