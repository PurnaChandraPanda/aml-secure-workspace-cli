data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

resource "random_uuid" "ra_aml_storage_blob" {}
resource "random_uuid" "ra_aml_storage_file" {}
resource "random_uuid" "ra_aml_acr_pull" {}
resource "random_uuid" "ra_aml_kv_secrets" {}


# ---------------------------------------------------------------------
# VNet + subnet in network RG
# ---------------------------------------------------------------------

resource "azapi_resource" "vnet" {
  count = var.create_vnet ? 1 : 0

  type      = "Microsoft.Network/virtualNetworks@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = local.resource_names.vnet
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      addressSpace = {
        addressPrefixes = var.vnet_address_space
      }
    }
  }
}

resource "azapi_resource" "subnet_private_endpoints" {
  count = var.create_private_endpoint_subnet ? 1 : 0

  type      = "Microsoft.Network/virtualNetworks/subnets@2023-11-01"
  parent_id = local.vnet_id
  name      = local.resource_names.pe_subnet

  body = {
    properties = {
      addressPrefixes                   = var.private_endpoint_subnet_prefixes
      privateEndpointNetworkPolicies    = "Disabled"
      privateLinkServiceNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azapi_resource.vnet,
    terraform_data.network_input_validation
  ]
}

resource "terraform_data" "network_input_validation" {
  input = {
    create_vnet                         = var.create_vnet
    existing_vnet_id                    = var.existing_vnet_id
    create_private_endpoint_subnet      = var.create_private_endpoint_subnet
    existing_private_endpoint_subnet_id = var.existing_private_endpoint_subnet_id
  }

  lifecycle {
    precondition {
      condition = (
        var.create_vnet ||
        var.existing_vnet_id != null ||
        !var.create_private_endpoint_subnet
      )
      error_message = "When create_vnet=false and create_private_endpoint_subnet=true, existing_vnet_id must be provided."
    }

    precondition {
      condition = (
        var.create_private_endpoint_subnet ||
        var.existing_private_endpoint_subnet_id != null
      )
      error_message = "When create_private_endpoint_subnet=false, existing_private_endpoint_subnet_id must be provided."
    }

    precondition {
      condition = (
        var.create_private_dns_zone_vnet_links == false ||
        local.vnet_id != null
      )
      error_message = "When create_private_dns_zone_vnet_links=true, local.vnet_id must be available. Provide existing_vnet_id or set create_vnet=true."
    }
  }
}

# ---------------------------------------------------------------------
# Private DNS zones in network RG
# ---------------------------------------------------------------------

resource "azapi_resource" "private_dns_zones" {
  for_each = local.private_dns_zones_to_create

  type      = "Microsoft.Network/privateDnsZones@2020-06-01"
  parent_id = local.network_resource_group_id
  name      = each.value
  location  = "global"

  body = {
    tags = var.tags
  }
}

resource "azapi_resource" "pdz_vnet_links" {
  for_each = var.create_private_dns_zone_vnet_links ? local.private_dns_zone_ids : {}

  type      = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  parent_id = each.value
  name      = "link-${each.key}-${local.suffix}"
  location  = "global"

  body = {
    tags = var.tags

    properties = {
      registrationEnabled = false

      virtualNetwork = {
        id = local.vnet_id
      }
    }
  }

  depends_on = [
    azapi_resource.private_dns_zones
  ]
}

# ---------------------------------------------------------------------
# Platform resources in platform RG
# ---------------------------------------------------------------------

resource "azapi_resource" "log_analytics" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.log_analytics
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      sku = {
        name = "PerGB2018"
      }

      retentionInDays = 30
    }
  }
}

resource "azapi_resource" "app_insights" {
  type      = "Microsoft.Insights/components@2020-02-02"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.app_insights
  location  = var.location

  body = {
    kind = "web"
    tags = var.tags

    properties = {
      Application_Type                = "web"
      WorkspaceResourceId             = azapi_resource.log_analytics.id
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
      RetentionInDays                 = 90
      SamplingPercentage              = 100
    }
  }
}

resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.storage
  location  = var.location

  body = {
    kind = "StorageV2"
    tags = var.tags

    sku = {
      name = "Standard_${var.storage_replication_type}"
    }

    properties = {
      accessTier                   = "Hot"
      allowBlobPublicAccess        = false
      allowCrossTenantReplication  = false
      allowSharedKeyAccess         = true
      defaultToOAuthAuthentication = false
      minimumTlsVersion            = "TLS1_2"
      publicNetworkAccess          = "Disabled"
      supportsHttpsTrafficOnly     = true

      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Deny"
        ipRules             = []
        virtualNetworkRules = []
      }

      encryption = {
        keySource = "Microsoft.Storage"

        services = {
          blob = {
            enabled = true
            keyType = "Account"
          }

          file = {
            enabled = true
            keyType = "Account"
          }
        }
      }
    }
  }
}

resource "azapi_resource" "key_vault" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.key_vault
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      tenantId                     = data.azapi_client_config.current.tenant_id
      enableRbacAuthorization      = true
      enableSoftDelete             = true
      softDeleteRetentionInDays    = 7
      enablePurgeProtection        = true
      enabledForDeployment         = false
      enabledForDiskEncryption     = false
      enabledForTemplateDeployment = false
      publicNetworkAccess          = "Disabled"

      sku = {
        family = "A"
        name   = "standard"
      }

      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Deny"
        ipRules             = []
        virtualNetworkRules = []
      }

      accessPolicies = []
    }
  }
}

resource "azapi_resource" "acr" {
  type      = "Microsoft.ContainerRegistry/registries@2023-07-01"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.acr
  location  = var.location

  body = {
    tags = var.tags

    sku = {
      name = var.acr_sku
    }

    properties = {
      adminUserEnabled         = false
      publicNetworkAccess      = "Disabled"
      networkRuleBypassOptions = "AzureServices"
    }
  }
}

# ---------------------------------------------------------------------
# Azure ML workspace using AzAPI
# ---------------------------------------------------------------------

resource "azapi_resource" "aml_workspace" {
  type      = "Microsoft.MachineLearningServices/workspaces@2025-06-01"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.aml_workspace
  location  = var.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    tags = var.tags

    properties = {
      applicationInsights = azapi_resource.app_insights.id
      storageAccount      = azapi_resource.storage.id
      keyVault            = azapi_resource.key_vault.id
      containerRegistry   = azapi_resource.acr.id

      publicNetworkAccess = "Disabled"

      # Ask AML RP to provision the managed network during workspace deployment
      provisionNetworkNow = true

      managedNetwork = {
        isolationMode      = var.aml_managed_network_isolation_mode
        managedNetworkKind = "V1"
      }
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.managedNetwork"
  ]

  schema_validation_enabled = false

  depends_on = [
    azapi_resource.storage,
    azapi_resource.key_vault,
    azapi_resource.acr,
    azapi_resource.app_insights,
    azapi_resource.pdz_vnet_links
  ]
}


# ---------------------------------------------------------------------
# Private endpoints in customer-managed VNet
# ---------------------------------------------------------------------

resource "azapi_resource" "pe_aml_workspace" {
  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.aml_workspace}"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.aml_workspace}"

          properties = {
            privateLinkServiceId = azapi_resource.aml_workspace.id
            groupIds             = ["amlworkspace"]
            requestMessage       = "Private endpoint for AML workspace"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints,
    azapi_resource.aml_workspace
  ]
}

resource "azapi_resource" "pdzg_pe_aml_workspace" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_aml_workspace.id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "aml-api"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["aml_api"]
          }
        },
        {
          name = "aml-notebooks"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["aml_notebooks"]
          }
        }
      ]
    }
  }
}

resource "azapi_resource" "pe_storage_blob" {
  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.storage}-blob"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.storage}-blob"

          properties = {
            privateLinkServiceId = azapi_resource.storage.id
            groupIds             = ["blob"]
            requestMessage       = "Private endpoint for Storage blob"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints
  ]
}

resource "azapi_resource" "pdzg_pe_storage_blob" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_storage_blob.id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "storage-blob"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["storage_blob"]
          }
        }
      ]
    }
  }
}

resource "azapi_resource" "pe_storage_file" {
  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.storage}-file"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.storage}-file"

          properties = {
            privateLinkServiceId = azapi_resource.storage.id
            groupIds             = ["file"]
            requestMessage       = "Private endpoint for Storage file"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints
  ]
}

resource "azapi_resource" "pdzg_pe_storage_file" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_storage_file.id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "storage-file"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["storage_file"]
          }
        }
      ]
    }
  }
}

resource "azapi_resource" "pe_key_vault" {
  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.key_vault}"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.key_vault}"

          properties = {
            privateLinkServiceId = azapi_resource.key_vault.id
            groupIds             = ["vault"]
            requestMessage       = "Private endpoint for Key Vault"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints
  ]
}

resource "azapi_resource" "pdzg_pe_key_vault" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_key_vault.id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "keyvault"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["key_vault"]
          }
        }
      ]
    }
  }
}

resource "azapi_resource" "pe_acr" {
  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.acr}"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.acr}"

          properties = {
            privateLinkServiceId = azapi_resource.acr.id
            groupIds             = ["registry"]
            requestMessage       = "Private endpoint for ACR"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints
  ]
}

resource "azapi_resource" "pdzg_pe_acr" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_acr.id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "acr"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["acr"]
          }
        }
      ]
    }
  }
}

# ---------------------------------------------------------------------
# Azure Monitor Private Link Scope
# ---------------------------------------------------------------------

resource "azapi_resource" "ampls" {
  count = var.existing_ampls_id == null ? 1 : 0

  type      = "Microsoft.Insights/privateLinkScopes@2021-07-01-preview"
  parent_id = local.platform_resource_group_id
  name      = local.resource_names.ampls
  location  = "global"

  body = {
    tags = var.tags

    properties = {
      accessModeSettings = {
        ingestionAccessMode = "Open"
        queryAccessMode     = "Open"
      }
    }
  }
}

resource "azapi_resource" "ampls_log_analytics" {
  type      = "Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview"
  parent_id = local.ampls_id
  name      = "ampls-svc-log-${local.suffix}"

  body = {
    properties = {
      linkedResourceId = azapi_resource.log_analytics.id
    }
  }
}

resource "azapi_resource" "ampls_app_insights" {
  type      = "Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview"
  parent_id = local.ampls_id
  name      = "ampls-svc-appi-${local.suffix}"

  body = {
    properties = {
      linkedResourceId = azapi_resource.app_insights.id
    }
  }
}

resource "azapi_resource" "pe_ampls" {
  count = var.create_ampls_private_endpoint ? 1 : 0

  type      = "Microsoft.Network/privateEndpoints@2023-11-01"
  parent_id = local.network_resource_group_id
  name      = "pe-${local.resource_names.ampls}"
  location  = var.location

  body = {
    tags = var.tags

    properties = {
      subnet = {
        id = local.private_endpoint_subnet_id
      }

      privateLinkServiceConnections = [
        {
          name = "psc-${local.resource_names.ampls}"

          properties = {
            privateLinkServiceId = local.ampls_id
            groupIds             = ["azuremonitor"]
            requestMessage       = "Private endpoint for Azure Monitor Private Link Scope"
          }
        }
      ]
    }
  }

  depends_on = [
    terraform_data.network_input_validation,
    azapi_resource.subnet_private_endpoints,
    azapi_resource.ampls_log_analytics,
    azapi_resource.ampls_app_insights
  ]
}

resource "azapi_resource" "pdzg_pe_ampls" {
  count = var.create_ampls_private_endpoint ? 1 : 0

  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id = azapi_resource.pe_ampls[0].id
  name      = "default"

  body = {
    properties = {
      privateDnsZoneConfigs = [
        {
          name = "monitor"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["monitor"]
          }
        },
        {
          name = "oms"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["oms"]
          }
        },
        {
          name = "ods"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["ods"]
          }
        },
        {
          name = "agentsvc"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["agentsvc"]
          }
        },
        {
          name = "blob"

          properties = {
            privateDnsZoneId = local.private_dns_zone_ids["storage_blob"]
          }
        }
      ]
    }
  }
}


# Explicit action: provision managed virtual network
resource "azapi_resource_action" "provision_aml_managed_network" {
  type        = "Microsoft.MachineLearningServices/workspaces@2026-03-15-preview"
  resource_id = azapi_resource.aml_workspace.id
  action      = "provisionManagedNetwork"

  body = {
    includeSpark = false
  }

  depends_on = [
    azapi_resource.aml_workspace
  ]
}
