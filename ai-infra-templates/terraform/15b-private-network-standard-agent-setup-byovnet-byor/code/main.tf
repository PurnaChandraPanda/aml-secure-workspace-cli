########## Create infrastructure resources
##########

## Create a random string
##
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

########## Create resoures required to for agent data storage
##########

## Create a storage account for agent data
##
resource "azurerm_storage_account" "storage_account" {

  ## In terraform, `count` is a meta-argument on a resource block.
  ## When a resource block includes count, Terraform creates that many instances of the resource. If count = 1, Terraform creates one instance; if count = 0, Terraform creates none.
  ## Skip creation if an existing_storage_account_id is supplied.
  count = var.existing_storage_account_id == null ? 1 : 0

  provider = azurerm.workload_subscription

  name                = "aifoundry${random_string.unique.result}storage"
  resource_group_name = var.resource_group_name_resources
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  ## Identity configuration
  shared_access_key_enabled = false

  ## Network access configuration
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    bypass = [
      "AzureServices"
    ]
  }
}

## Create the Cosmos DB account to store agent threads
##
resource "azurerm_cosmosdb_account" "cosmosdb" {

  ## Skip creation when existing_cosmos_account_id is supplied
  count = var.existing_cosmos_account_id == null ? 1 : 0

  provider = azurerm.workload_subscription

  name                = "aifoundry${random_string.unique.result}cosmosdb"
  location            = var.location
  resource_group_name = var.resource_group_name_resources

  # General settings
  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  # Set security-related settings
  local_authentication_disabled = true
  public_network_access_enabled = false

  # Set high availability and failover settings
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false

  # Configure consistency settings
  consistency_policy {
    consistency_level = "Session"
  }

  # Configure single location with no zone redundancy to reduce costs
  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }
}

## Create an AI Search instance that will be used to store vector embeddings
##
resource "azapi_resource" "ai_search" {

  ## Skip creation when existing_search_service_id is supplied
  count = var.existing_search_service_id == null ? 1 : 0

  provider = azapi.workload_subscription

  type                      = "Microsoft.Search/searchServices@2025-05-01"
  name                      = "aifoundry${random_string.unique.result}search"
  parent_id                 = "/subscriptions/${var.subscription_id_resources}/resourceGroups/${var.resource_group_name_resources}"
  location                  = var.location
  schema_validation_enabled = true

  body = {
    sku = {
      name = "standard"
    }

    identity = {
      type = "SystemAssigned"
    }

    properties = {

      # Search-specific properties
      replicaCount   = 1
      partitionCount = 1
      hostingMode    = "Default"
      semanticSearch = "disabled"

      # Identity-related controls
      disableLocalAuth = false
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }
      # Networking-related controls
      publicNetworkAccess = "Disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

########## Create AI Foundry resource
##########

## Create the AI Foundry resource
##
resource "azapi_resource" "ai_foundry" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = "aifoundry${random_string.unique.result}"
  parent_id                 = "/subscriptions/${var.subscription_id_resources}/resourceGroups/${var.resource_group_name_resources}"
  location                  = var.location
  schema_validation_enabled = false

  body = {
    kind = "AIServices",
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {
      # Support both Entra ID and API Key authentication for underlining Cognitive Services account
      disableLocalAuth = false

      # Specifies that this is an AI Foundry resource
      allowProjectManagement = true

      # Set custom subdomain name for DNS names created for this Foundry resource
      customSubDomainName = "aifoundry${random_string.unique.result}"

      # Network-related controls
      # Disable public access but allow Trusted Azure Services exception
      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction = "Allow"
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = var.subnet_id_agent
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }
}

## Create a deployment for OpenAI's GPT-4o in the AI Foundry resource
##
resource "azurerm_cognitive_deployment" "aifoundry_deployment_gpt_4o" {
  provider = azurerm.workload_subscription

  depends_on = [
    azapi_resource.ai_foundry
  ]

  name                 = "gpt-4o"
  cognitive_account_id = azapi_resource.ai_foundry.id

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }
}

########## Create Private DNS Zones, Links, and Private Endpoints
##########

## Create Private Endpoints for resources
##
resource "azurerm_private_endpoint" "pe_storage" {

  ## `count` is a Terraform meta-argument. When a resource block has count = 1, Terraform creates one instance; when count = 0, Terraform creates none.
  ## Skip PE creation when an existing storage account ID is provided and PE creation is disabled
  count = (
    var.existing_storage_account_id != null && !var.create_private_endpoints_for_existing_resources
  ) ? 0 : 1

  provider = azurerm.workload_subscription

  name                = "${local.storage_account_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  subnet_id           = var.subnet_id_private_endpoint
  private_service_connection {
    name                           = "${local.storage_account_name}-private-link-service-connection"
    private_connection_resource_id = local.storage_account_id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${local.storage_account_name}-dns-config"
    private_dns_zone_ids = [
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    ]
  }
}

resource "azurerm_private_endpoint" "pe_cosmosdb" {

  ## Skip PE creation when an existing cosmos account ARM id is provided and PE creation is disabled 
  count = (
    var.existing_cosmos_account_id != null && !var.create_private_endpoints_for_existing_resources
  ) ? 0 : 1

  provider = azurerm.workload_subscription

  name                = "${local.cosmos_account_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  subnet_id           = var.subnet_id_private_endpoint

  private_service_connection {
    name                           = "${local.cosmos_account_name}-private-link-service-connection"
    private_connection_resource_id = local.cosmos_account_id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${local.cosmos_account_name}-dns-config"
    private_dns_zone_ids = [
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com"
    ]
  }
}

resource "azurerm_private_endpoint" "pe_aisearch" {

  ## Skip PE creation when an existing search service account ARM id is provided and PE creation is disabled  
  count = (
    var.existing_search_service_id != null && !var.create_private_endpoints_for_existing_resources
  ) ? 0 : 1

  provider = azurerm.workload_subscription

  name                = "${local.search_service_name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  subnet_id           = var.subnet_id_private_endpoint

  private_service_connection {
    name                           = "${local.search_service_name}-private-link-service-connection"
    private_connection_resource_id = local.search_service_id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${local.search_service_name}-dns-config"
    private_dns_zone_ids = [
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
    ]
  }
}

resource "azurerm_private_endpoint" "pe_aifoundry" {
  provider = azurerm.workload_subscription
  
  depends_on = [
    azapi_resource.ai_foundry
  ]

  name                = "${azapi_resource.ai_foundry.name}-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name_resources
  subnet_id           = var.subnet_id_private_endpoint

  private_service_connection {
    name                           = "${azapi_resource.ai_foundry.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_foundry.id
    subresource_names = [
      "account"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_foundry.name}-dns-config"
    private_dns_zone_ids = [
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com",
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com",
      "/subscriptions/${var.subscription_id_infra}/resourceGroups/${var.resource_group_name_dns}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
    ]
  }
}

########## Create the AI Foundry project, project connections, role assignments, and project-level capability host
##########

## Create AI Foundry project
##
resource "azapi_resource" "ai_foundry_project" {
  provider = azapi.workload_subscription

  depends_on = [
    azapi_resource.ai_foundry,
    azurerm_private_endpoint.pe_storage,
    azurerm_private_endpoint.pe_cosmosdb,
    azurerm_private_endpoint.pe_aisearch,
    azurerm_private_endpoint.pe_aifoundry
  ]

  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = "project${random_string.unique.result}"
  parent_id                 = azapi_resource.ai_foundry.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {
      displayName = "project"
      description = "A project for the AI Foundry account with network secured deployed Agent"
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.internalId"
  ]
}

## Wait 10 seconds for the AI Foundry project system-assigned managed identity to be created and to replicate
## through Entra ID
resource "time_sleep" "wait_project_identities" {
  depends_on = [
    azapi_resource.ai_foundry_project
  ]
  create_duration = "10s"
}

## Create AI Foundry project connections
##
resource "azapi_resource" "conn_cosmosdb" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.cosmos_account_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.ai_foundry_project
  ]

  body = {
    name = local.cosmos_account_name
    properties = {
      category = "CosmosDb"
      target   = local.cosmos_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = local.cosmos_account_id
        location   = var.location
      }
    }
  }
}

## Create the AI Foundry project connection to Azure Storage Account
##
resource "azapi_resource" "conn_storage" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.storage_account_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.ai_foundry_project
  ]

  body = {
    name = local.storage_account_name
    properties = {
      category = "AzureStorageAccount"
      target   = local.storage_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = local.storage_account_id
        location   = var.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

## Create the AI Foundry project connection to AI Search
##
resource "azapi_resource" "conn_aisearch" {
  provider = azapi.workload_subscription

  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.search_service_name
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.ai_foundry_project
  ]

  body = {
    name = local.search_service_name
    properties = {
      category = "CognitiveSearch"
      target   = "https://${local.search_service_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = local.search_service_id
        location   = var.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

## Create the necessary role assignments for the AI Foundry project over the resources used to store agent data
##
resource "azurerm_role_assignment" "cosmosdb_operator_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${var.resource_group_name_resources}cosmosdboperator")
  scope                = local.cosmos_account_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_contributor_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${local.storage_account_name}storageblobdatacontributor")
  scope                = local.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_index_data_contributor_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${local.search_service_name}searchindexdatacontributor")
  scope                = local.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_service_contributor_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${local.search_service_name}searchservicecontributor")
  scope                = local.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
}

## Pause 60 seconds to allow for role assignments to propagate
##
resource "time_sleep" "wait_rbac" {
  depends_on = [
    azurerm_role_assignment.cosmosdb_operator_ai_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_ai_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_ai_foundry_project,
    azurerm_role_assignment.search_service_contributor_ai_foundry_project
  ]
  create_duration = "60s"
}

## Create the AI Foundry project capability host
##
resource "azapi_resource" "ai_foundry_project_capability_host" {
  provider = azapi.workload_subscription

  depends_on = [
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    time_sleep.wait_rbac
  ]
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.ai_foundry_project.id
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        local.search_service_name
      ]
      storageConnections = [
        local.storage_account_name
      ]
      threadStorageConnections = [
        local.cosmos_account_name
      ]
    }
  }
}

## Create the necessary data plane role assignments to the CosmosDb databases created by the AI Foundry Project.
## This gives the project identity the built-in data contributor role at the database level, which should cover:
#   ${local.project_id_guid}-thread-message-store
#   ${local.project_id_guid}-system-thread-message-store
#   ${local.project_id_guid}-agent-entity-store
#   ${local.project_id_guid}-agent-definitions-v1
#   and similar future containers created under `enterprise_memory`.
resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_enterprise_memory" {
  provider = azurerm.workload_subscription

  depends_on = [
    azapi_resource.ai_foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}entitystore_dbsqlrole")
  resource_group_name = local.cosmos_account_rg_name
  account_name        = local.cosmos_account_name
  scope               = "${local.cosmos_account_id}/dbs/enterprise_memory"
  role_definition_id  = "${local.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.ai_foundry_project.output.identity.principalId
}

## Create the necessary data plane role assignments to the Azure Storage Account containers created by the AI Foundry Project
##
resource "azurerm_role_assignment" "storage_blob_data_owner_ai_foundry_project" {
  provider = azurerm.workload_subscription

  depends_on = [
    azapi_resource.ai_foundry_project_capability_host
  ]
  name                 = uuidv5("dns", "${azapi_resource.ai_foundry_project.name}${azapi_resource.ai_foundry_project.output.identity.principalId}${local.storage_account_name}storageblobdataowner")
  scope                = local.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.ai_foundry_project.output.identity.principalId
  condition_version    = "2.0"
  condition            = <<-EOT
  (
    (
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})
      AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'})
      AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'})
    )
    OR
    (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase '${local.project_id_guid}'
    AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase '*-azureml-agent')
  )
  EOT
}
