### Fill in required azure resource details
$TENANT_ID="" # Set your Azure tenant ID
$SUBSCRIPTION_ID="" # Set your Azure subscription ID
$REGION="australiaeast" # Set your Azure region; e.g. australiaeast
$RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
$WORKSPACE_NAME="" # Set your Azure ML workspace name; e.g. mlworkspaces10092
# Vnet name where workspace is
$VNET_NAME="" # Set the vnet name where the workspace is located; e.g. uservnet
$SUBNET_NAME="" # Set your Azure ML workspace subnet name; e.g. mlsubnet
$VNET_RESOURCE_GROUP="" # Set your Azure ML workspace vnet resource group name; e.g. rg-vnet
$CLUSTER_NAME = "" # Set your Azure ML compute cluster name for image-build in own vnet; e.g. cpu-cluster
$UAI_ID_NAME = "" # Set your Azure user assigned identity name; e.g. mluai003
$SUBNET_ID = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"
# ARM-id of the UAI you want the cluster to run as
$IDENTITY_ID = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$UAI_ID_NAME"


# Login to Azure CLI
az login --tenant $TENANT_ID

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID

# Check on ml workspace
az ml workspace show --name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP

# Create a compute cluster in vnet with npip settings if not already created (conditional)
$clusterExists = az ml compute show `
                   --name           $CLUSTER_NAME `
                   --workspace-name $WORKSPACE_NAME `
                   --resource-group $RESOURCE_GROUP `
                   --output tsv 2>$null

if (-not $clusterExists) {
    Write-Host "Creating compute $CLUSTER_NAME"

    az ml compute create `
        --name            $CLUSTER_NAME `
        --workspace-name  $WORKSPACE_NAME `
        --resource-group  $RESOURCE_GROUP `
        --type            amlcompute `
        --size            Standard_DS11_v2 `
        --min-instances   0 `
        --max-instances   1 `
        --subnet          $SUBNET_ID `
        --enable-node-public-ip     true `
        --identity-type   UserAssigned `
        --user-assigned-identities $IDENTITY_ID `
        --location       $REGION `
        --only-show-errors
}
else {
    Write-Host "Compute $CLUSTER_NAME already exists - skipping"
}

# Setup the imagebuildcompute property on ml workspace if not set
$imgbuild_compute = az ml workspace show `
    --name $WORKSPACE_NAME `
    --resource-group $RESOURCE_GROUP `
    --query "image_build_compute" `
    --output tsv
if (-not $imgbuild_compute) {
    Write-Host "Setting image_build_compute property on workspace $WORKSPACE_NAME"
    az ml workspace update `
        --name $WORKSPACE_NAME `
        --resource-group $RESOURCE_GROUP `
        --image-build-compute $CLUSTER_NAME `
        --only-show-errors
} else {
    Write-Host "image_build_compute property already set on workspace $WORKSPACE_NAME - skipping"
}

Write-Host "preparation over for ml"
