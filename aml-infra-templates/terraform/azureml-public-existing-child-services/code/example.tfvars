# Sub/ RG/ Location details
subscription_id        = "69------------------------------03"
resource_group_name    = "rg-mygroup"
location               = "westeurope"

// New ml workspace details
workspace_name         = "amlws-prods-001"
friendly_name          = "AML Workspace Prod"
description            = "Azure ML workspace using existing KV, Storage, ACR and App Insights"

# ARM IDs of applicationInsights, KV, Storage, ACR resources
application_insights_id = "/subscriptions/697-----------------------------2103/resourceGroups/rg-mygroup/providers/microsoft.insights/components/myappinsightsname"
key_vault_id            = "/subscriptions/697-----------------------------2103/resourceGroups/rg-mygroup/providers/Microsoft.KeyVault/vaults/mykvname"
storage_account_id      = "/subscriptions/697-----------------------------2103/resourceGroups/rg-mygroup/providers/Microsoft.Storage/storageAccounts/mystoragename"
container_registry_id   = "/subscriptions/697-----------------------------2103/resourceGroups/rg-mygroup/providers/Microsoft.ContainerRegistry/registries/myacrname"

# Set PNA param
public_network_access      = "Enabled"

# Set datastore auth mode: Identity or AccessKey
system_datastores_auth_mode = "Identity"

tags = {
  environment = "prod"
  workload    = "azureml"
}