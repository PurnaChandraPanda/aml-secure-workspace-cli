targetScope = 'resourceGroup'

param amplsName string
param existingAmplsId string = ''
param tags object

var useExistingAmpls = !empty(existingAmplsId)
var existingAmplsName = useExistingAmpls ? last(split(existingAmplsId, '/')) : ''
var resolvedAmplsName = useExistingAmpls ? existingAmplsName : amplsName

resource ampls 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' = if (!useExistingAmpls) {
  name: amplsName
  location: 'global'
  tags: tags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'Open'
      queryAccessMode: 'Open'
    }
  }
}

output amplsId string = useExistingAmpls ? existingAmplsId : ampls.id
output amplsName string = resolvedAmplsName