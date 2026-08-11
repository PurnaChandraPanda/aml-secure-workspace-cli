### Fill in required azure resource details
$TENANT_ID="16b3c013-d300-468d-ac64-7eda0820b6d3" # Set your Azure tenant ID
$SUBSCRIPTION_ID="6977e295-0d7c-4557-8e0b-26e2f6532103" # Set your Azure subscription ID
$REGION="eastus2" # Set your Azure region; e.g. australiaeast
$RESOURCE_GROUP="rg-std2" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
$STORAGE_ACCOUNT="aifoundry3738storage" # Set your Storage account name; e.g. aifoundry3738storage
$BLOB_CONTAINER="nasa-ebooks-pdfs-all" # Set your blob container name; e.g. nasa-ebooks-pdfs-all

$REPO_URL = "https://github.com/Azure-Samples/azure-search-sample-data.git" # source remote folder where required data files reside
$REPO_ROOT = "azure-search-sample-data"
$REPO_LOCAL_PATH = "nasa-e-book/earth_book_2019_text_pages"
$DEST_PREFIX = "_data"   # put blobs under this virtual folder in the container


# Login to Azure CLI
# az login --tenant $TENANT_ID

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID

# RBAC check - list role assignments for the user on the storage account
$acctId = az storage account show --name $STORAGE_ACCOUNT --query id -o tsv

# Returns the object ID (GUID) of the currently logged-in user
$OID=$(az ad signed-in-user show --query id -o tsv)
Write-Host "On storage account $acctId, roles for oid: $OID are: " -ForegroundColor Cyan
az role assignment list --assignee-object-id "$OID" --scope "$acctId" --include-inherited -o table

# Ensure blob container exists
$container_exists = az storage container exists `
                                    --account-name $STORAGE_ACCOUNT `
                                    --name $BLOB_CONTAINER `
                                    --auth-mode login `
                                    --query "exists" -o tsv

if ($container_exists -ne "true") {
  Write-Host "Container does not exist. Creating: $BLOB_CONTAINER" -ForegroundColor Yellow

  $created = (az storage container create `
                  --account-name $STORAGE_ACCOUNT `
                  --name $BLOB_CONTAINER `
                  --auth-mode login `
                  --public-access off `
                  --query "created" -o tsv).Trim().ToLowerInvariant()

  if ($created -ne "true") {
    throw "Failed to create container '$BLOB_CONTAINER' in storage account '$STORAGE_ACCOUNT'."
  }

  Write-Host "Container created: $BLOB_CONTAINER" -ForegroundColor Green
}
else {
  Write-Host "Container already exists: $BLOB_CONTAINER" -ForegroundColor Green
}

# Download the folder locally (sparse checkout), then upload PDFs
$REPO_LOCAL = Join-Path $PSScriptRoot $REPO_ROOT
$LOCAL_FOLDER = Join-Path $REPO_LOCAL $REPO_LOCAL_PATH

if (-not (Test-Path $REPO_LOCAL)) {
  
  git clone --depth 1 --filter=blob:none --sparse $REPO_URL $REPO_LOCAL
  if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

  # changes the current working directory to $REPO_LOCAL
  # And it pushes the previous directory onto a location stack, so you can return later with popd
  pushd $REPO_LOCAL
  
  # Update the sparse-checkout file to include the specific subfolder
  git sparse-checkout set $REPO_LOCAL_PATH
  if ($LASTEXITCODE -ne 0) { popd; throw "git sparse-checkout failed" }
  popd
}

if (-not (Test-Path $LOCAL_FOLDER)) {
  throw "Local folder not found: $LOCAL_FOLDER"
}

write-Host "Local folder ready at: $LOCAL_FOLDER" -ForegroundColor Green

Write-Host "Uploading the PDFs from local folder $LOCAL_FOLDER to container $BLOB_CONTAINER under prefix $DEST_PREFIX ..."

# ====== Upload the entire local folder using current user identity ======
# Prefer upload-batch with destination-path to keep the 'data/' prefix in the container
az storage blob upload-batch `
  --account-name $STORAGE_ACCOUNT `
  --destination $BLOB_CONTAINER `
  --source $LOCAL_FOLDER `
  --destination-path $DEST_PREFIX `
  --pattern "*.pdf" `
  --overwrite `
  --auth-mode login

# ====== Verify ======
az storage blob list `
  --account-name $STORAGE_ACCOUNT `
  --container-name $BLOB_CONTAINER `
  --prefix "$DEST_PREFIX/" `
  --auth-mode login `
  -o table

# Cleanup local repo folder if desired
if (Test-Path $REPO_LOCAL) {
  Remove-Item -Path $REPO_LOCAL -Recurse -Force
  write-Host "Local repo folder removed: $REPO_LOCAL" -ForegroundColor CYAN
}

Write-Host "------ Data preparation over for RAG -----" -ForegroundColor Green
