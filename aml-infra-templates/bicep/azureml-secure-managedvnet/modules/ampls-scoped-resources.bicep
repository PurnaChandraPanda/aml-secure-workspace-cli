targetScope = 'resourceGroup'

param amplsName string
param logAnalyticsId string
param appInsightsId string

resource scopedLog 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: '${amplsName}/ampls-svc-log-${uniqueString(logAnalyticsId)}'
  properties: {
    linkedResourceId: logAnalyticsId
  }
}

resource scopedAppi 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: '${amplsName}/ampls-svc-appi-${uniqueString(appInsightsId)}'
  properties: {
    linkedResourceId: appInsightsId
  }
}