using './main.bicep'

// -----------------------------
// Common
// -----------------------------
param location = 'uksouth'

// -----------------------------
// Resource groups
// -----------------------------
param workspacePrefix = 'uks76'
// Customer-owned networking RG: VNet, subnets, private DNS zones, private endpoints
param networkResourceGroupName = 'rg-uks76discovery-network'

// Microsoft Discovery resource RG: UAMI, storage account, supercomputer, workspace, project
param discoveryResourceGroupName = 'rg-uks76discovery'

// -----------------------------
// Customer-owned VNet
// -----------------------------
param networkMode = 'create'
param vnetName = 'vnet-disc-demo-0076'
param vnetAddressPrefix = '10.0.0.0/16'

// Dedicated subnets for Discovery E2E hardened setup
param agentSubnetPrefix = '10.0.1.0/24'
param workspaceSubnetPrefix = '10.0.2.0/24'
param privateEndpointSubnetPrefix = '10.0.3.0/27'
param searchSubnetPrefix = '10.0.4.0/27'
param aksSubnetPrefix = '10.0.5.0/24'
param supercomputerNodepoolSubnetPrefix = '10.0.6.0/24'
param storagePrivateEndpointSubnetPrefix = '10.0.11.0/27'

// -----------------------------
// Discovery resources
// -----------------------------
param supercomputerName = 'sc-demo-0076'
param nodePoolName = 'nodepool76'

param workspaceName = 'ws-uks76demo-0076'


// -----------------------------
// Identity and storage
// -----------------------------
param managedIdentityName = 'uami-uks76discovery'

// Must be globally unique, lowercase, 3-24 chars, no hyphen
param storageAccountName = 'stguks76discovery001'

param blobContainerName = 'discoveryoutputs'


// Supply full ARM IDs if central/pre-existing zones are used.
param workspacePrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.workspace.discovery.azure.com'
param blobPrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
param createPrivateDnsZonesWhenMissing = false

// false: network.bicep creates DNS zones and VNet links (or vnet already linked)
// true: dns-links.bicep is only for central/pre-existing DNS zones (or vnet not linked)
param createPrivateDnsVnetLinks = true

param privateDnsZoneSubscriptionId = '11-----------------------03'
param privateDnsZoneResourceGroupName = 'rg-uks6discovery-network'