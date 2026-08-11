### Fill in required azure resource details
$TENANT_ID="" # Set your Azure tenant ID
$SUBSCRIPTION_ID="" # Set your Azure subscription ID
$REGION="" # Set your Azure region; e.g. eastus2
$RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
$WORKSPACE_NAME="" # Set your Azure ML workspace name; e.g. mlworkspaces10092

$LOCAL_FOLDER = ".\spark\data"  # local folder you want to upload
$DEST_PREFIX = "data"   # put blobs under this virtual folder in the container


# Login to Azure CLI
az login --tenant $TENANT_ID

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID

# Check on ml workspace
$WS_ID = $(az ml workspace show `
                        --name $WORKSPACE_NAME `
                        --resource-group $RESOURCE_GROUP `
                        --query id -o tsv 2>$null)

if (-not $WS_ID) {
    Write-Host "ML Workspace $WORKSPACE_NAME not found in resource group $RESOURCE_GROUP" -ForegroundColor Red
    exit 1
}

Write-Host "ML Workspace found: $WS_ID"

# Read default datastore info - with account_name, container_name, type details
$blob_datastore = az ml datastore show --name workspaceblobstore `
                                        --workspace-name $WORKSPACE_NAME `
                                        --resource-group $RESOURCE_GROUP `
                                        -o json | ConvertFrom-Json

Write-Host "Default blob datastore info:"
Write-Host "Storage account name: $($blob_datastore.account_name)"
Write-Host "Blob Container name: $($blob_datastore.container_name)"

# RBAC check - list role assignments for the user on the storage account
$acctId = az storage account show --name $blob_datastore.account_name --query id -o tsv
# Returns the object ID (GUID) of the currently logged-in user
$OID=$(az ad signed-in-user show --query id -o tsv)
az role assignment list --scope "$acctId" --assignee "$OID" -o table

# Ensure blob container exists
$container_exists = az storage container exists `
                                    --account-name $blob_datastore.account_name `
                                    --name $blob_datastore.container_name `
                                    --auth-mode login `
                                    --query "exists" -o tsv

if ($container_exists -ne "true") {
  Write-Host "Container does not exist: $($blob_datastore.container_name)" -ForegroundColor Red
  exit 1
}

Write-Host "Uploading the blob files from local folder $LOCAL_FOLDER to container $($blob_datastore.container_name) under prefix $DEST_PREFIX ..."

# ====== Upload the entire local folder using current user identity ======
# Prefer upload-batch with destination-path to keep the 'data/' prefix in the container
az storage blob upload-batch `
  --account-name $blob_datastore.account_name `
  --destination $blob_datastore.container_name `
  --source $LOCAL_FOLDER `
  --destination-path $DEST_PREFIX `
  --pattern "*.csv" `
  --overwrite `
  --auth-mode login

# ====== Verify ======
az storage blob list `
  --account-name $blob_datastore.account_name `
  --container-name $blob_datastore.container_name `
  --prefix "$DEST_PREFIX/" `
  --auth-mode login `
  -o table

Write-Host "preparation over for ml"
