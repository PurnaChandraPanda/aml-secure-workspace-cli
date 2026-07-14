using './main.bicep'

// -----------------------------
// Common
// -----------------------------
param location = 'uksouth'

// -----------------------------
// Resource groups
// -----------------------------
param workspacePrefix = 'uks98'
// Customer-owned networking RG: VNet, subnets, private DNS zones, private endpoints
param networkResourceGroupName = 'rg-uks6discovery-network'

// Microsoft Discovery resource RG: UAMI, storage account, supercomputer, workspace, project
param discoveryResourceGroupName = 'rg-uks8discovery'

// -----------------------------
// Customer-owned VNet
// -----------------------------
param networkMode = 'existing'
param vnetName = 'vnet-disc-demo-006'
param vnetAddressPrefix = '10.0.0.0/16'

// Dedicated subnets for Discovery E2E hardened setup
// Fresh non-overlapping subnet slice for new Discovery workspace (that is already created)
param existingVnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006'

param existingAgentSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-agent-ws'
param existingWorkspaceSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-workspace-ws'
param existingPrivateEndpointSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-pe-ws'
param existingSearchSubnetId = '//subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-bs-search'
param existingAksSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-sc-aks'
param existingSupercomputerNodepoolSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-sc-nodepool'
param existingStoragePrivateEndpointSubnetId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/virtualNetworks/vnet-disc-demo-006/subnets/uk78-pe-storage'

// Pass the subnet prefix range as empty as reading existing subnet IDs
param agentSubnetPrefix = ''
param workspaceSubnetPrefix = ''
param privateEndpointSubnetPrefix = ''
param searchSubnetPrefix = ''
param aksSubnetPrefix = ''
param supercomputerNodepoolSubnetPrefix = ''
param storagePrivateEndpointSubnetPrefix = ''

// -----------------------------
// Discovery resources
// -----------------------------
param supercomputerName = 'sc-demo-008'
param nodePoolName = 'nodepool8'

param workspaceName = 'ws-uks8demo-008'

// -----------------------------
// Identity and storage
// -----------------------------
param managedIdentityName = 'uami-uks8discovery'

// Must be globally unique, lowercase, 3-24 chars, no hyphen
param storageAccountName = 'stguks8discovery001'

param blobContainerName = 'discoveryoutputs'


// Since DNS zones already exist from previous deployment in same network RG,
// supply their ARM IDs and do NOT create new zones
param workspacePrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.workspace.discovery.azure.com'
param blobPrivateDnsZoneId = '/subscriptions/11-----------------------03/resourceGroups/rg-uks6discovery-network/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
param createPrivateDnsZonesWhenMissing = false

// false: network.bicep creates DNS zones and VNet links (or vnet already linked)
// true: dns-links.bicep is only for central/pre-existing DNS zones (or vnet not linked)
param createPrivateDnsVnetLinks = false

param privateDnsZoneSubscriptionId = '11-----------------------03'
param privateDnsZoneResourceGroupName = 'rg-uks6discovery-network'
