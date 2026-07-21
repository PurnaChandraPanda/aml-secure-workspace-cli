## Microsoft Discovery Infrastructure Templates

This repository contains Bicep templates and helper scripts for deploying Microsoft Discovery infrastructure in both public-access and end-to-end network-hardened patterns.

## Deployment folders

| Folder | Purpose |
|---|---|
| `public-discovery` | Basic Microsoft Discovery infrastructure deployment where public access is allowed. Best for simple validation, demos, and non-restricted environments. |
| `e2e-network-discovery` | End-to-end network-hardened deployment with customer-owned VNet, private endpoints, Private DNS, VPN validation, and Discovery workspace created with public network access disabled. |

## Network hardening notes

- Do not use the Discovery managed resource group VNet for customer or user data-plane access.

- The Discovery managed resource group and managed VNet are for Discovery-managed backend resources and service components. 
- Microsoft Discovery network hardening protects managed resources using mechanisms such as Network Security Perimeters and managed-resource private endpoints, while workspace/ bookshelf data-plane private endpoints are a separate layer used for API traffic to workspace or bookshelf services.

- For customer or user access to the Discovery workspace data-plane endpoint, use a customer-owned VNet and create a workspace private endpoint. Microsoft Discovery documents workspace private endpoint support with group ID `workspace` and Private DNS zone `privatelink.workspace.discovery.azure.com`.

## Cleanup resources
Follow [Discovery cleanup](./.scripts/readme.md) script.

## References
- [Network security in Discovery](https://learn.microsoft.com/en-us/azure/microsoft-discovery/concept-network-security)
