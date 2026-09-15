##########
# Create Azure Monitor resources for agent tracing
##########
#
# Public monitoring mode:
#   enable_public_monitoring_access = true
#   - Application Insights public ingestion/query enabled
#   - Log Analytics public ingestion/query enabled
#   - AMPLS and Azure Monitor private endpoint not created
#
# Private monitoring mode:
#   enable_public_monitoring_access = false
#   - Application Insights public ingestion/query disabled
#   - Log Analytics public ingestion/query disabled
#   - AMPLS and Azure Monitor private endpoint created
#
# The Foundry project connection and monitoring role assignments are created in both modes.

## Create the Log Analytics workspace that backs Application Insights

resource "azurerm_log_analytics_workspace" "loganalytics" {
  provider = azurerm.workload_subscription

  name                = "loganalytics-tracing-${random_string.unique.result}"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  sku                 = "PerGB2018"
  retention_in_days   = 30

  internet_ingestion_enabled = var.enable_public_monitoring_access
  internet_query_enabled     = var.enable_public_monitoring_access
}

## Create workspace-based Application Insights

resource "azurerm_application_insights" "app_insights" {
  provider = azurerm.workload_subscription

  name                = "appinsights-tracing-${random_string.unique.result}"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  workspace_id        = azurerm_log_analytics_workspace.loganalytics.id
  application_type    = "web"

  internet_ingestion_enabled = var.enable_public_monitoring_access
  internet_query_enabled     = var.enable_public_monitoring_access
}

## Create Azure Monitor Private Link Scope only for private monitoring mode

resource "azurerm_monitor_private_link_scope" "ampls" {
  count = local.deploy_private_monitoring ? 1 : 0

  provider = azurerm.workload_subscription

  name                  = "ampls-tracing-${random_string.unique.result}"
  resource_group_name   = var.resource_group_name_resources
  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
}

## Add Application Insights to AMPLS

resource "azurerm_monitor_private_link_scoped_service" "ampls_app_insights" {
  count = local.deploy_private_monitoring ? 1 : 0

  provider = azurerm.workload_subscription

  name                = "appinsights-scoped"
  resource_group_name = var.resource_group_name_resources
  scope_name          = azurerm_monitor_private_link_scope.ampls[0].name
  linked_resource_id  = azurerm_application_insights.app_insights.id
}

## Add Log Analytics to AMPLS

resource "azurerm_monitor_private_link_scoped_service" "ampls_loganalytics" {
  count = local.deploy_private_monitoring ? 1 : 0

  provider = azurerm.workload_subscription

  name                = "loganalytics-scoped"
  resource_group_name = var.resource_group_name_resources
  scope_name          = azurerm_monitor_private_link_scope.ampls[0].name
  linked_resource_id  = azurerm_log_analytics_workspace.loganalytics.id
}

## Create the AMPLS private endpoint only for private monitoring mode

resource "azurerm_private_endpoint" "pe_ampls" {
  count = local.deploy_private_monitoring ? 1 : 0

  provider = azurerm.workload_subscription

  depends_on = [
    azurerm_monitor_private_link_scoped_service.ampls_app_insights,
    azurerm_monitor_private_link_scoped_service.ampls_loganalytics
  ]

  name                = "ampls-tracing-${random_string.unique.result}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  subnet_id           = var.subnet_id_private_endpoint

  private_service_connection {
    name                           = "ampls-tracing-private-link-service-connection"
    private_connection_resource_id = azurerm_monitor_private_link_scope.ampls[0].id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "ampls-tracing-dns-config"

    private_dns_zone_ids = [
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.monitor.azure.com",
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.oms.opinsights.azure.com",
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.ods.opinsights.azure.com",
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.agentsvc.azure-automation.net"
    ]
  }
}

## Connect the Foundry project to Application Insights

resource "azapi_resource" "conn_app_insights" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = azurerm_application_insights.app_insights.name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.ai_foundry_project
  ]

  body = {
    name = azurerm_application_insights.app_insights.name

    properties = {
      category = "AppInsights"
      target   = azurerm_application_insights.app_insights.id
      authType = "ApiKey"

      credentials = {
        key = azurerm_application_insights.app_insights.connection_string
      }

      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.app_insights.id
        location   = var.location
      }
    }
  }
}

## Grant the Foundry project managed identity monitoring read access

resource "azurerm_role_assignment" "log_analytics_reader_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]

  name = uuidv5(
    "dns",
    "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.resource_group_name_resources}loganalyticsreader"
  )

  scope                = azurerm_application_insights.app_insights.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "privileged_monitoring_data_reader_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]

  name = uuidv5(
    "dns",
    "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.resource_group_name_resources}privmonitoringdatareader"
  )

  scope                = azurerm_application_insights.app_insights.id
  role_definition_name = "Privileged Monitoring Data Reader"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}