targetScope = 'resourceGroup'

param vnetId string
param existingPrivateDnsZoneIds object = {}
param createPrivateDnsZoneVnetLinks bool = true
param linkSuffix string
param tags object

var zoneNames = {
  aml_api: 'privatelink.api.azureml.ms'
  aml_notebooks: 'privatelink.notebooks.azure.net'
  storage_blob: 'privatelink.blob.core.windows.net'
  storage_file: 'privatelink.file.core.windows.net'
  key_vault: 'privatelink.vaultcore.azure.net'
  acr: 'privatelink.azurecr.io'
  monitor: 'privatelink.monitor.azure.com'
  oms: 'privatelink.oms.opinsights.azure.com'
  ods: 'privatelink.ods.opinsights.azure.com'
  agentsvc: 'privatelink.agentsvc.azure-automation.net'
}

var zoneKeys = items(zoneNames)

resource zones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for z in zoneKeys: if (!contains(existingPrivateDnsZoneIds, z.key)) {
  name: z.value
  location: 'global'
  tags: tags
}]

var privateDnsZoneIds = {
  aml_api: existingPrivateDnsZoneIds.?aml_api ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.aml_api)
  aml_notebooks: existingPrivateDnsZoneIds.?aml_notebooks ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.aml_notebooks)
  storage_blob: existingPrivateDnsZoneIds.?storage_blob ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.storage_blob)
  storage_file: existingPrivateDnsZoneIds.?storage_file ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.storage_file)
  key_vault: existingPrivateDnsZoneIds.?key_vault ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.key_vault)
  acr: existingPrivateDnsZoneIds.?acr ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.acr)
  monitor: existingPrivateDnsZoneIds.?monitor ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.monitor)
  oms: existingPrivateDnsZoneIds.?oms ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.oms)
  ods: existingPrivateDnsZoneIds.?ods ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.ods)
  agentsvc: existingPrivateDnsZoneIds.?agentsvc ?? resourceId('Microsoft.Network/privateDnsZones', zoneNames.agentsvc)
}

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for z in zoneKeys: if (createPrivateDnsZoneVnetLinks) {
  name: '${z.value}/link-${z.key}-${linkSuffix}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
  dependsOn: [
    zones
  ]
}]

output privateDnsZoneIds object = privateDnsZoneIds
