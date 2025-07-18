set -e

## Set the Azure resource details
export TENANT_ID="" # Set your Azure tenant ID
export SUBSCRIPTION_ID="" # Set your Azure subscription ID
export REGION="" # Set your Azure region; e.g. australiaeast

export VNET_RESOURCE_GROUP="" # Set your VNet resource group name; e.g. rg-vnet
export VNET_NAME="" # Set your VNet name; e.g. uservnet
export SUBNET_NAME="" # Set your subnet name for ml; e.g. mlsubnet
export VNET_ADDRESS_PREFIX="10.0.0.0/16" # Set your VNet address prefix
export ML_SUBNET_ADDRESS_PREFIX="10.0.0.0/24" # Set your subnet address prefix for ml
export NSG_NAME="defaultsubnetnsg" # Set your subnet network security group name

export STORAGE_ACCOUNT_ACCESS="identity" # Set your storage account access type (identity or credential); default is credential; set to identity for UAI use
export IDENTITY_NAME="" # Set your user-assigned identity name; e.g. mluai003
export RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
export STORAGE_ACCOUNT_NAME="" # Set your unique storage account name; e.g. mlstorage10092
export KV_NAME="" # Set your unique Azure Key Vault name; e.g. mlkv10092
export ACR_NAME="" # Set your unique Azure Container Registry name; e.g. mlacr10092
export WORKSPACE_NAME="" # Set your unique Azure ML workspace name; e.g. mlworkspaces10092
export NEW_WORKSPACE_YML="new-uai-privateworkspace.yml" # Set your new workspace yml file name
export APPLICATION_INSIGHTS_NAME="" # Set your unique Application Insights name; e.g. mlappinsights10092
export WORKSPACE_PL_YML="workspace-privatelink.yml" # Set your workspace private link yml file name

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

# Set the current user login - to authenticate with Azure CLI 
# interactively against the other tenant if current user may be mapped to multiple tenants
az login --tenant $TENANT_ID --use-device-code
# # For managed identity, you can use the following command to login current tenant
# az login --identity
# Set the subscription id
az account set --subscription $SUBSCRIPTION_ID 

# Create vnet resource group if does not exist
{ # try
    RG_RESULT=$(az group show --resource-group $VNET_RESOURCE_GROUP --query name -o tsv)
    if [ -z $RG_RESULT ]; then
        echo "create resource group ..."
        az group create -l $REGION -n $VNET_RESOURCE_GROUP
    else
        echo "resource group exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create vnet if does not exist
{ # try
    VNET_RESULT=$(az network vnet show --resource-group $VNET_RESOURCE_GROUP --name $VNET_NAME --query name -o tsv)
    if [ -z $VNET_RESULT ]; then
        echo "create vnet + subnet ..."
        az network vnet create --address-prefixes $VNET_ADDRESS_PREFIX --name $VNET_NAME --resource-group $VNET_RESOURCE_GROUP --subnet-name $SUBNET_NAME --subnet-prefixes $ML_SUBNET_ADDRESS_PREFIX --location $REGION
    else
        echo "vnet exists"
    fi
} || {
    # catch exception 
    echo "not found"
}

# ---------------------------------------------------------------------------
# Create a default NSG and attach it to the subnet
# ---------------------------------------------------------------------------
if ! az network nsg show --resource-group "$VNET_RESOURCE_GROUP" \
                         --name "$NSG_NAME" --only-show-errors >/dev/null 2>&1; then
    echo "Creating NSG $NSG_NAME …"
    az network nsg create \
        --resource-group "$VNET_RESOURCE_GROUP" \
        --location       "$REGION" \
        --name           "$NSG_NAME" \
        --only-show-errors
else
    echo "NSG $NSG_NAME already exists"
fi

echo "Checking NSG association on subnet …"
SUBNET_NSG_ID=$(az network vnet subnet show \
    --resource-group "$VNET_RESOURCE_GROUP" \
    --vnet-name      "$VNET_NAME" \
    --name           "$SUBNET_NAME" \
    --query "networkSecurityGroup.id" -o tsv 2>/dev/null)
if [[ -z "$SUBNET_NSG_ID" || "$SUBNET_NSG_ID" != */$NSG_NAME ]]; then
    echo "Associating NSG with subnet …"
    az network vnet subnet update \
        --resource-group "$VNET_RESOURCE_GROUP" \
        --vnet-name      "$VNET_NAME" \
        --name           "$SUBNET_NAME" \
        --network-security-group "$NSG_NAME" \
        --only-show-errors
else
    echo "NSG $NSG_NAME is already associated with the subnet."
fi

echo "VNet and subnet setup complete with NSG."

# Create ml resource group if does not exist
{ # try
    RG_RESULT=$(az group show --resource-group $RESOURCE_GROUP --query name -o tsv)
    if [ -z $RG_RESULT ]; then
        echo "create resource group ..."
        az group create -l $REGION -n $RESOURCE_GROUP
    else
        echo "resource group $RESOURCE_GROUP exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# ---------------------------------------------------------------------------
# Create user-assigned identity only when requested
# ---------------------------------------------------------------------------
if [[ "$STORAGE_ACCOUNT_ACCESS" == "identity" ]]; then
    echo "Storage access = identity -> ensuring UAI $IDENTITY_NAME …"
    if ! az identity show --resource-group "$RESOURCE_GROUP" \
                          --name "$IDENTITY_NAME" --only-show-errors >/dev/null 2>&1; then
        az identity create \
            --resource-group "$RESOURCE_GROUP" \
            --location       "$REGION" \
            --name           "$IDENTITY_NAME" \
            --only-show-errors
    else
        echo "UAI $IDENTITY_NAME already exists"
    fi
fi

# Create storage account if does not exist; 
## with access key use disabled;
## with bypass set to AzureServices by default;
## with public network access disabled;
## with tls version set to TLS1_2;
{ # try
    STORAGE_ACCOUNT_RESULT=$(az storage account show --resource-group $RESOURCE_GROUP --name $STORAGE_ACCOUNT_NAME --query name -o tsv)
    if [ -z $STORAGE_ACCOUNT_RESULT ]; then
        echo "create storage account ..."
        az storage account create \
        --name                  "$STORAGE_ACCOUNT_NAME" \
        --resource-group        "$RESOURCE_GROUP" \
        --location              "$REGION" \
        --access-tier           Hot \
        --sku                   Standard_LRS \
        --allow-shared-key-access false \
        --public-network-access Disabled \
        --min-tls-version TLS1_2 \
        --only-show-errors
    else
        echo "storage account $STORAGE_ACCOUNT_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create KV if does not exist
## with rbac permission model by default;
## with bypass set to AzureServices;
## with public network access disabled;
{ # try
    KV_RESULT=$(az keyvault show --resource-group $RESOURCE_GROUP --name $KV_NAME --query name -o tsv)
    if [ -z $KV_RESULT ]; then
        echo "create kv resource ..."
        az keyvault create \
        --name                  "$KV_NAME" \
        --resource-group        "$RESOURCE_GROUP" \
        --location              "$REGION" \
        --bypass               AzureServices \
        --public-network-access Disabled \
        --only-show-errors
    else
        echo "Keyvault $KV_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create ACR resource if does not exist
## with sku set to Premium;
## with admin access key disabled by default;
## with allow-trusted-services set to true by default;
## with public network access disabled;
{ # try
    ACR_RESULT=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query name -o tsv)
    if [ -z $ACR_RESULT ]; then
        echo "create acr resource ..."
        az acr create \
        --name                  "$ACR_NAME" \
        --resource-group        "$RESOURCE_GROUP" \
        --location              "$REGION" \
        --sku                   Premium \
        --public-network-enabled False \
        --only-show-errors
    else
        echo "ACR $ACR_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create Application Insights resource if does not exist
{ # try
    APP_INSIGHTS_RESULT=$(az monitor app-insights component show \
                            --resource-group $RESOURCE_GROUP \
                            --app $APPLICATION_INSIGHTS_NAME 
                            --query name -o tsv 2>/dev/null || true)
    if [[ -z "$APP_INSIGHTS_RESULT" ]]; then
        echo "create application insights resource ..."
        az monitor app-insights component create \
        --app                   "$APPLICATION_INSIGHTS_NAME" \
        --location              "$REGION" \
        --resource-group        "$RESOURCE_GROUP" \
        --application-type      web \
        --only-show-errors
    else
        echo "Application Insights $APPLICATION_INSIGHTS_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Export ARM ID values for further use
export STORAGE_ACCOUNT_ID KV_ID ACR_ID IDENTITY_ID APP_INSIGHTS_ID

# Read ARM ID of the storage account
STORAGE_ACCOUNT_ID=$(az storage account show \
                        --resource-group $RESOURCE_GROUP \
                        --name $STORAGE_ACCOUNT_NAME \
                        --query id -o tsv)
# echo $STORAGE_ACCOUNT_ID
# Read ARM ID of the Key Vault
KV_ID=$(az keyvault show \
                --resource-group $RESOURCE_GROUP \
                --name $KV_NAME \
                --query id -o tsv)
# echo $KV_ID
# Read ARM ID of the ACR
ACR_ID=$(az acr show \
                --resource-group $RESOURCE_GROUP \
                --name $ACR_NAME \
                --query id -o tsv)
# echo $ACR_ID
# Read ARM ID of the user-assigned identity
IDENTITY_ID=$(az identity show --resource-group "$RESOURCE_GROUP" \
                                --name "$IDENTITY_NAME" --query id -o tsv)
# echo $IDENTITY_ID

# Read ARM ID of the application insights
APP_INSIGHTS_ID=$(az monitor app-insights component show \
                        --resource-group $RESOURCE_GROUP \
                        --app $APPLICATION_INSIGHTS_NAME \
                        --query id -o tsv)
# echo $APP_INSIGHTS_ID

# Assign UAI the required RBAC roles
## RG level: contributor
## Storage Account level: Storage Blob Data Contributor, Storage File Privileged Data Contributor
## KV level: Key Vault Administrator
## ACR level: AcrPull, AcrPush
## Add condition that if role already exists, do not assign it again

## Read ARM-ID and principal-ID of the user-assigned identity
IDENTITY_RES_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query id -o tsv)
IDENTITY_OBJ_ID=$(az identity show -g "$RESOURCE_GROUP" -n "$IDENTITY_NAME" --query principalId -o tsv)
echo "Identity objectId: $IDENTITY_OBJ_ID"

assign_role() {
  local principal_oid="$1"   # object-id / appId
  local role="$2"        # role name or id
  local scope="$3"

  local existing_role_assignment
  existing_role_assignment=$(az role assignment list \
        --assignee-object-id "$principal_oid" \
        --role "$role" \
        --scope "$scope" \
        --query '[0]' -o tsv)
  if [[ -z "$existing_role_assignment" ]]; then
        echo "Adding $role on $scope"
        az role assignment create \
            --assignee-object-id "$principal_oid" \
            --role "$role" \
            --scope "$scope" \
            --only-show-errors
  else
      echo "$role already present on $scope - skipping"
  fi
}

## Contributor on the RG
assign_role "$IDENTITY_OBJ_ID" "Contributor" \
            "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

## Storage roles
assign_role "$IDENTITY_OBJ_ID" "Storage Blob Data Contributor" "$STORAGE_ACCOUNT_ID"
assign_role "$IDENTITY_OBJ_ID" "Storage File Data Privileged Contributor" "$STORAGE_ACCOUNT_ID"

## Key Vault roles
assign_role "$IDENTITY_OBJ_ID" "Key Vault Administrator" "$KV_ID"

## ACR roles
assign_role "$IDENTITY_OBJ_ID" "AcrPull" "$ACR_ID"
assign_role "$IDENTITY_OBJ_ID" "AcrPush" "$ACR_ID"

VARS='$WORKSPACE_NAME $RESOURCE_GROUP $TENANT_ID \
      $STORAGE_ACCOUNT_ID $ACR_ID $KV_ID $IDENTITY_ID $APP_INSIGHTS_ID'

tmp_yaml=$(mktemp)
envsubst "$VARS" < "$NEW_WORKSPACE_YML" > "$tmp_yaml"

# Create workspace if does not exist
{ # try
    WORKSPACE_RESULT=$(az ml workspace show \
                            --resource-group    "$RESOURCE_GROUP" \
                            --name              "$WORKSPACE_NAME" \
                            --query name -o tsv)
    if [ -z $WORKSPACE_RESULT ]; then
        echo "create workspace ..."
        az ml workspace create \
            --file          "$tmp_yaml" \
            --location      "$REGION" \
            --only-show-errors
    else
        echo "workspace $WORKSPACE_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}
rm "$tmp_yaml"

# Add pe for storage - blob, file
./storage-in-vnet.sh "$STORAGE_ACCOUNT_ID"

# Add pe for Key Vault
./vault-in-vnet.sh "$KV_ID"

# Add pe for ACR
./registry-in-vnet.sh "$ACR_ID"

# Add pe for workspace
./workspace-in-vnet.sh

echo "*** All resources created and configured successfully in private network."
echo "*** Work on jumpbox or leverage vnet gateway to access the workspace and other resources."
echo "*** Then, run workload based code/ scripts from the client machine."

