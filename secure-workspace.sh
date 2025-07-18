set -e

# subscription id of workspace
export SUBSCRIPTION_ID="" #9998------9b41
# resource group of workspace
export RESOURCE_GROUP="" #vnetwspp003rg
# workspace name
export WORKSPACE_NAME="" #vnetwspp003
# name of yml file that helps update workspace to allow only private access
export WORKSPACE_PL_YML="workspace-privatelink.yml"
# region where workspace is
export REGION="" #centralindia

# resource group of vnet
export VNET_RESOURCE_GROUP="" #vnet-rg
# vnet name where workspace is
export VNET_NAME="" #testvnet
# subnet name where workspace is
export SUBNET_NAME="" #amlsubnet

# for private dns zones, the names shared are pretty much the standard in ml scenarios
# private dns zone of worksapce api
export WORKSPACE_PRIVATE_DNS_ZONE="privatelink.api.azureml.ms"
# private dns zone of worksapce notebook
export WORKSPACE_NB_PRIVATE_DNS_ZONE="privatelink.notebooks.azure.net"
# private dns zone of storage file
export STORAGE_FILE_PRIVATE_DNS_ZONE="privatelink.file.core.windows.net"
# private dns zone of storage blob
export STORAGE_BLOB_PRIVATE_DNS_ZONE="privatelink.blob.core.windows.net"
# private dns zone of keyvault
export VAULT_PRIVATE_DNS_ZONE="privatelink.vaultcore.azure.net"
# private dns zone of acr
export REGISTRY_PRIVATE_DNS_ZONE="privatelink.azurecr.io"
# dns zone group for all private dns zone - it is set to default, but can be any name
export PRIVATE_DNS_ZONE_GROUP="default"

echo "bash automation script is started"

# Read storage account resource id from workspace
storage_account_resource_id=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "storage_account" -o tsv)
# add pe for storage - blob, file
sh ./storage-in-vnet.sh "$storage_account_resource_id"
# Read keyvault resource id from workspace
key_vault_resource=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "key_vault" -o tsv)
# add pe for keyvault
sh ./vault-in-vnet.sh "$key_vault_resource"
# Read acr resource id from workspace
acr_resource=$(az ml workspace show --resource-group $RESOURCE_GROUP --name $WORKSPACE_NAME --query "container_registry" -o tsv)
# add pe for registry
sh ./registry-in-vnet.sh "$acr_resource"
# add pe for workspace - api, notebook
sh ./workspace-in-vnet.sh

echo "bash automation script is completed"