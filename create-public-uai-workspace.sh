set -e

## Set the Azure resource details
export TENANT_ID="" # Set your Azure tenant ID
export SUBSCRIPTION_ID="" # Set your Azure subscription ID
export REGION="" # Set your Azure region; e.g. australiaeast

export STORAGE_ACCOUNT_ACCESS="identity" # Set your storage account access type (identity or credential); default is credential; set to identity for UAI use
export IDENTITY_NAME="" # Set your user-assigned identity name; e.g. mluai003
export RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-pubeaml092
export STORAGE_ACCOUNT_NAME="" # Set your unique storage account name; e.g. mlstorage10092
export KV_NAME="" # Set your unique Azure Key Vault name; e.g. mlkv10092
export ACR_NAME="" # Set your unique Azure Container Registry name; e.g. mlacr10092
export WORKSPACE_NAME="" # Set your unique Azure ML workspace name; e.g. mlworkspaces10092
export NEW_WORKSPACE_YML="new-uai-publicworkspace.yml" # Set your new workspace yml file name
export APPLICATION_INSIGHTS_NAME="" # Set your unique Application Insights name; e.g. mlappinsights10092



# Set the current user login - to authenticate with Azure CLI 
# interactively against the other tenant if current user may be mapped to multiple tenants
# az login --tenant $TENANT_ID --use-device-code
# # For managed identity, you can use the following command to login current tenant
az login --identity
# Set the subscription id
az account set --subscription $SUBSCRIPTION_ID 


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
## with public network access enabled;
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
        --public-network-access Enabled \
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
## with public network access enabled;
{ # try
    KV_RESULT=$(az keyvault show --resource-group $RESOURCE_GROUP --name $KV_NAME --query name -o tsv)
    if [ -z $KV_RESULT ]; then
        echo "create kv resource ..."
        az keyvault create \
        --name                  "$KV_NAME" \
        --resource-group        "$RESOURCE_GROUP" \
        --location              "$REGION" \
        --public-network-access Enabled \
        --only-show-errors
    else
        echo "Keyvault $KV_NAME exists"
    fi
} || { 
    # catch exception 
    echo "not found"
}

# Create ACR resource if does not exist
## with sku set to Basic;
## with admin access key disabled by default;
## with public network access enabled;
{ # try
    ACR_RESULT=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query name -o tsv)
    if [ -z $ACR_RESULT ]; then
        echo "create acr resource ..."
        az acr create \
        --name                  "$ACR_NAME" \
        --resource-group        "$RESOURCE_GROUP" \
        --location              "$REGION" \
        --sku                   Basic \
        --public-network-enabled True \
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
    echo "workspace result: $WORKSPACE_RESULT"
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

echo "*** All resources created and configured successfully in public network with UAI."
echo "*** Then, run workload based code/ scripts from the client machine."

