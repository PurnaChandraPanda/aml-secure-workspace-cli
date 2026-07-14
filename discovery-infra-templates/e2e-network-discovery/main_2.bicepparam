using './main.bicep'

// -----------------------------
// Common
// -----------------------------
param location = 'uksouth'

// -----------------------------
// Resource groups
// -----------------------------
param workspacePrefix = 'uks77'
// Customer-owned networking RG: VNet, subnets, private DNS zones, private endpoints
param networkResourceGroupName = 'rg-uks6discovery-network'

// Microsoft Discovery resource RG: UAMI, storage account, supercomputer, workspace, project
param discoveryResourceGroupName = 'rg-uks7discovery'

// -----------------------------
// Customer-owned VNet
// -----------------------------
param networkMode = 'existingVnetCreateSubnets'
param vnetName = 'vnet-disc-demo-006'
param vnetAddressPrefix = '10.0.0.0/16'

// Dedicated subnets for Discovery E2E hardened setup
// Fresh non-overlapping subnet slice for new Discovery workspace
param agentSubnetPrefix = '10.0.21.0/24'
param workspaceSubnetPrefix = '10.0.22.0/24'
param privateEndpointSubnetPrefix = '10.0.23.0/27'
param searchSubnetPrefix = '10.0.24.0/27'
param aksSubnetPrefix = '10.0.25.0/24'
param supercomputerNodepoolSubnetPrefix = '10.0.26.0/24'
param storagePrivateEndpointSubnetPrefix = '10.0.31.0/27'

// -----------------------------
// Discovery resources
// -----------------------------
param supercomputerName = 'sc-demo-007'
param nodePoolName = 'nodepool7'

param workspaceName = 'ws-uks7demo-007'

// -----------------------------
// Identity and storage
// -----------------------------
param managedIdentityName = 'uami-uks7discovery'

// Must be globally unique, lowercase, 3-24 chars, no hyphen
param storageAccountName = 'stguks7discovery001'

param blobContainerName = 'discoveryoutputs'


// Since DNS zones already exist from previous deployment in same network RG,
// supply their ARM IDs and do NOT create new zones
// Supply full ARM IDs if central/pre-existing zones are used.
param workspacePrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.workspace.discovery.azure.com'
param blobPrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
param createPrivateDnsZonesWhenMissing = false

// false: network.bicep creates DNS zones and VNet links (or vnet already linked)
// true: dns-links.bicep is only for central/pre-existing DNS zones (or vnet not linked)
param createPrivateDnsVnetLinks = false

param privateDnsZoneSubscriptionId = '11-----------------------03'
param privateDnsZoneResourceGroupName = 'rg-uks6discovery-network'
