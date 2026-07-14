targetScope = 'resourceGroup'

@description('Existing customer-owned VNet resource ID.')
param vnetId string

@description('Existing dedicated agent workload subnet ID.')
param agentSubnetId string

@description('Existing dedicated workspace services subnet ID.')
param workspaceSubnetId string

@description('Existing dedicated workspace data-plane private endpoint subnet ID.')
param privateEndpointSubnetId string

@description('Existing dedicated bookshelf/search subnet ID.')
param searchSubnetId string

@description('Existing dedicated supercomputer AKS/system subnet ID.')
param aksSubnetId string

@description('Existing dedicated supercomputer nodepool subnet ID.')
param supercomputerNodepoolSubnetId string

@description('Existing dedicated customer storage private endpoint subnet ID.')
param storagePrivateEndpointSubnetId string

@description('Existing Private DNS zone ARM ID for Discovery workspace data-plane.')
param workspacePrivateDnsZoneId string

@description('Existing Private DNS zone ARM ID for Storage Blob.')
param blobPrivateDnsZoneId string

output vnetId string = vnetId

output agentSubnetId string = agentSubnetId
output workspaceSubnetId string = workspaceSubnetId
output privateEndpointSubnetId string = privateEndpointSubnetId
output searchSubnetId string = searchSubnetId
output aksSubnetId string = aksSubnetId
output supercomputerNodepoolSubnetId string = supercomputerNodepoolSubnetId
output storagePrivateEndpointSubnetId string = storagePrivateEndpointSubnetId

output effectiveWorkspacePrivateDnsZoneId string = workspacePrivateDnsZoneId
output effectiveBlobPrivateDnsZoneId string = blobPrivateDnsZoneId
