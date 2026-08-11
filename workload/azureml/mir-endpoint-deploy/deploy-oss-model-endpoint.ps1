$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------
# Required Azure resource details
# ---------------------------------------------------------------------
# subscription where azureml/ azure ai hub exists
$SUBSCRIPTION_ID = "75--------------------------------86"
# tenant id
$TENANT_ID       = "7f--------------------------------d2"
# region where azure resource is
$REGION          = "eastus2"
# resource group of azureml / ai hub
$RESOURCE_GROUP  = "rg-pupanda5"
# name of azureml workspace or ai hub project
$WORKSPACE_NAME  = "proj-hubsec-7ygm70"

# Model from AzureML model catalog / registry
$OSS_MODEL_ID = "azureml://registries/azureml-voyage/models/voyage-3.5-embedding-model/versions/2"

# ---------------------------------------------------------------------
# Endpoint/deployment settings
# ---------------------------------------------------------------------
# Endpoint name must be unique in the Azure region.
# Keep lowercase, numbers, and hyphen.
$ENDPOINT_NAME   = "voyage35-7ygm70-43strict"
$DEPLOYMENT_NAME = "blue"

# IMPORTANT:
# Pick the SKU recommended by the model card if this one does not fit.
# For model catalog OSS models, GPU SKU is often needed.
$INSTANCE_TYPE  = "Standard_NC24ads_A100_v4"
$INSTANCE_COUNT = 1

# Working folder for generated YAML
$WORK_DIR = Join-Path $PSScriptRoot ".generated"
New-Item -ItemType Directory -Force -Path $WORK_DIR | Out-Null

$ENDPOINT_YAML   = Join-Path $WORK_DIR "endpoint.yml"
$DEPLOYMENT_YAML = Join-Path $WORK_DIR "deployment.yml"

# ---------------------------------------------------------------------
# Azure login/context
# ---------------------------------------------------------------------
Write-Host "Setting Azure subscription context..."
az account set --subscription $SUBSCRIPTION_ID

# ---------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------
Write-Host "Checking workspace exists..."
az ml workspace show `
  --resource-group $RESOURCE_GROUP `
  --name $WORKSPACE_NAME `
  --query "{name:name, location:location}" `
  -o table

Write-Host "Checking workspace v1 legacy mode..."
$WORKSPACE_ID = az ml workspace show `
  --resource-group $RESOURCE_GROUP `
  --name $WORKSPACE_NAME `
  --query id `
  -o tsv

# Managed online endpoints require v1 legacy mode to be off.
# If this returns true, update the workspace before deploying.
$V1_LEGACY_MODE = az resource show `
  --ids $WORKSPACE_ID `
  --api-version "2025-06-01" `
  --query "properties.v1LegacyMode" `
  -o tsv 2>$null

Write-Host "Workspace v1LegacyMode: $V1_LEGACY_MODE"

if ($V1_LEGACY_MODE -eq "true") {
  throw "Workspace v1LegacyMode is true. Managed online endpoint creation can fail. Set v1_legacy_mode=false first."
}

# ---------------------------------------------------------------------
# Generate endpoint YAML
# ---------------------------------------------------------------------
@"
name: $ENDPOINT_NAME
auth_mode: key
location: $REGION
public_network_access: disabled
"@ | Set-Content -Path $ENDPOINT_YAML -Encoding UTF8

# ---------------------------------------------------------------------
# Generate deployment YAML
# ---------------------------------------------------------------------
@"
name: $DEPLOYMENT_NAME
endpoint_name: $ENDPOINT_NAME
model: $OSS_MODEL_ID
instance_type: $INSTANCE_TYPE
instance_count: $INSTANCE_COUNT
egress_public_network_access: enabled
"@ | Set-Content -Path $DEPLOYMENT_YAML -Encoding UTF8

Write-Host "Generated endpoint YAML:"
Get-Content $ENDPOINT_YAML

Write-Host "`nGenerated deployment YAML:"
Get-Content $DEPLOYMENT_YAML

# ---------------------------------------------------------------------
# Create or update endpoint
# ---------------------------------------------------------------------
Write-Host "`nCreating/updating managed online endpoint with public network access disabled..."
az ml online-endpoint create `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $WORKSPACE_NAME `
  --file $ENDPOINT_YAML

# ---------------------------------------------------------------------
# Create or update deployment
# ---------------------------------------------------------------------
Write-Host "`nCreating/updating deployment with egress public network access enabled..."
try {
  az ml online-deployment create `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --file $DEPLOYMENT_YAML

  # Set the traffic 100% to the new deployment
  Write-Host "`nSetting traffic to 100% for deployment $DEPLOYMENT_NAME..."
  az ml online-endpoint update `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --name $ENDPOINT_NAME `
    --traffic "$DEPLOYMENT_NAME=100"
}
catch {
  Write-Host "`nDeployment failed. Fetching deployment logs if available..." -ForegroundColor Yellow

  az ml online-deployment get-logs `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --endpoint-name $ENDPOINT_NAME `
    --name $DEPLOYMENT_NAME `
    --lines 200

  throw
}

# ---------------------------------------------------------------------
# Confirm endpoint/deployment
# ---------------------------------------------------------------------
Write-Host "`nEndpoint:"
az ml online-endpoint show `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $WORKSPACE_NAME `
  --name $ENDPOINT_NAME `
  --query "{name:name, provisioningState:provisioning_state, publicNetworkAccess:public_network_access, scoringUri:scoring_uri}" `
  -o jsonc

Write-Host "`nDeployment:"
az ml online-deployment show `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $WORKSPACE_NAME `
  --endpoint-name $ENDPOINT_NAME `
  --name $DEPLOYMENT_NAME `
  --query "{name:name, provisioningState:provisioning_state, egressPublicNetworkAccess:egress_public_network_access, instanceType:instance_type, instanceCount:instance_count}" `
  -o jsonc

Write-Host "`nDone."
Write-Host "Endpoint name: $ENDPOINT_NAME"
Write-Host "Deployment name: $DEPLOYMENT_NAME"
