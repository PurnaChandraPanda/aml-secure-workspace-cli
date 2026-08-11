<#
.SYNOPSIS
  Consume a deployed Azure ML managed online endpoint exposing a Voyage embeddings route.

.DESCRIPTION
  This script sends a POST request to:
    https://<endpoint-host>.<region>.inference.ml.azure.com/embeddings

  It is designed for an Azure ML managed online endpoint created with:
    auth_mode: key
    public_network_access: disabled

  For PNA disabled endpoints, run this from a machine/network that can resolve/reach
  the endpoint private endpoint, for example via VPN/private DNS.

.NOTES
  Requires:
    - Azure CLI
    - Azure ML CLI extension: az extension add -n ml
    - az login completed
#>

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

# ---------------------------------------------------------------------
# Endpoint/deployment settings
# ---------------------------------------------------------------------
# IMPORTANT:
# Use the actual Azure ML endpoint name here.
# If your endpoint name is different from the hostname, keep the correct AML endpoint name.
$ENDPOINT_NAME   = "voyage35-7ygm70-43strict"
$DEPLOYMENT_NAME = "blue"

# Model name expected by the model server.
# This should match what your model route expects, based on your curl sample.
$MODEL_NAME = "voyage-3.5"

# Texts to embed.
# Add more strings here if needed.
$INPUT_TEXTS = @(
  "Sample text to embed"
)

# ---------------------------------------------------------------------
# Working folder/files
# ---------------------------------------------------------------------
$WORK_DIR = Join-Path $PSScriptRoot ".generated"
New-Item -ItemType Directory -Force -Path $WORK_DIR | Out-Null

$REQUEST_JSON  = Join-Path $WORK_DIR "voyage35-embeddings-request.json"
$RESPONSE_JSON = Join-Path $WORK_DIR "voyage35-embeddings-response.json"

# ---------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------
function Assert-CommandExists {
  param(
    [Parameter(Mandatory = $true)]
    [string] $CommandName
  )

  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "Required command '$CommandName' was not found in PATH."
  }
}

function Write-Section {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Message
  )

  Write-Host ""
  Write-Host "====================================================================="
  Write-Host $Message
  Write-Host "====================================================================="
}

function Get-AmlEndpointKey {
  param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string] $EndpointName
  )

  Write-Host "Retrieving endpoint primary key from Azure ML..."

  $key = az ml online-endpoint get-credentials `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --name $EndpointName `
    --query primaryKey `
    -o tsv

  if ([string]::IsNullOrWhiteSpace($key)) {
    throw "Could not retrieve primaryKey for endpoint '$EndpointName'. Check endpoint name, workspace, RBAC, and auth_mode."
  }

  return $key
}

function Get-EmbeddingsUri {
  param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $WorkspaceName,

    [Parameter(Mandatory = $true)]
    [string] $EndpointName
  )

  Write-Host "Reading scoring_uri from Azure ML endpoint..."

  $scoringUri = az ml online-endpoint show `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --name $EndpointName `
    --query scoring_uri `
    -o tsv

  if ([string]::IsNullOrWhiteSpace($scoringUri)) {
    throw "Could not read scoring_uri for endpoint '$EndpointName'."
  }

  # Return the scoring_uri
  # Note: modify the uri if your model server expects a different route
  return $scoringUri
}

function Test-EndpointNetwork {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Uri
  )

  $parsed = [System.Uri]::new($Uri)
  $hostName = $parsed.Host

  Write-Host "Endpoint host:"
  Write-Host "  $hostName"

  Write-Host ""
  Write-Host "DNS resolution:"
  try {
    Resolve-DnsName -Name $hostName -ErrorAction Stop | Select-Object Name, Type, IPAddress, NameHost | Format-Table -AutoSize
  }
  catch {
    Write-Host "DNS resolution failed for $hostName" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "TCP 443 connectivity:"
  try {
    $tcpResult = Test-NetConnection -ComputerName $hostName -Port 443 -WarningAction SilentlyContinue
    $tcpResult | Select-Object ComputerName, RemoteAddress, RemotePort, TcpTestSucceeded | Format-List

    if (-not $tcpResult.TcpTestSucceeded) {
      Write-Host "TCP 443 check failed. If public_network_access is disabled, verify VPN, PE, private DNS, and routing." -ForegroundColor Yellow
    }
  }
  catch {
    Write-Host "TCP test failed for $hostName" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
  }
}

# ---------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------
Write-Section "Pre-flight checks"

Assert-CommandExists -CommandName "az"

Write-Host "Setting Azure subscription context..."
az account set --subscription $SUBSCRIPTION_ID

Write-Host "Verifying Azure login context..."
az account show `
  --query "{subscriptionId:id, tenantId:tenantId, user:user.name}" `
  -o jsonc

Write-Host ""
Write-Host "Checking Azure ML CLI extension..."
$mlExt = az extension show --name ml --query "{name:name, version:version}" -o json 2>$null | ConvertFrom-Json

if ($null -eq $mlExt) {
  Write-Host "Azure ML CLI extension not found. Installing extension 'ml'..."
  az extension add --name ml
}
else {
  Write-Host "Azure ML CLI extension found: $($mlExt.name) $($mlExt.version)"
}

Write-Host ""
Write-Host "Checking workspace..."
az ml workspace show `
  --resource-group $RESOURCE_GROUP `
  --name $WORKSPACE_NAME `
  --query "{name:name, location:location}" `
  -o table

Write-Host ""
Write-Host "Checking endpoint..."
$endpointInfo = az ml online-endpoint show `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $WORKSPACE_NAME `
  --name $ENDPOINT_NAME `
  --query "{name:name, provisioningState:provisioning_state, authMode:auth_mode, publicNetworkAccess:public_network_access, scoringUri:scoring_uri}" `
  -o json | ConvertFrom-Json

$endpointInfo | ConvertTo-Json -Depth 10

if ($endpointInfo.provisioningState -ne "Succeeded") {
  throw "Endpoint provisioning state is '$($endpointInfo.provisioningState)'. Expected 'Succeeded'."
}

if ($endpointInfo.authMode -ne "key") {
  Write-Host ""
  Write-Host "WARNING: Endpoint auth_mode appears to be '$($endpointInfo.authMode)', not 'key'." -ForegroundColor Yellow
  Write-Host "This script is currently using endpoint key as Bearer token." -ForegroundColor Yellow
  Write-Host "If you changed endpoint auth_mode to aad_token, use an AAD token instead of endpoint key." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking deployment..."
$deploymentInfo = az ml online-deployment show `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $WORKSPACE_NAME `
  --endpoint-name $ENDPOINT_NAME `
  --name $DEPLOYMENT_NAME `
  --query "{name:name, provisioningState:provisioning_state, instanceType:instance_type, instanceCount:instance_count}" `
  -o json | ConvertFrom-Json

$deploymentInfo | ConvertTo-Json -Depth 10

if ($deploymentInfo.provisioningState -ne "Succeeded") {
  throw "Deployment provisioning state is '$($deploymentInfo.provisioningState)'. Expected 'Succeeded'."
}

# ---------------------------------------------------------------------
# Prepare request
# ---------------------------------------------------------------------
Write-Section "Preparing request"

$embeddingsUri = Get-EmbeddingsUri `
  -ResourceGroup $RESOURCE_GROUP `
  -WorkspaceName $WORKSPACE_NAME `
  -EndpointName $ENDPOINT_NAME

$payload = [ordered]@{
  input = $INPUT_TEXTS
  model = $MODEL_NAME
}

$payloadJson = $payload | ConvertTo-Json -Depth 20
$payloadJson | Set-Content -Path $REQUEST_JSON -Encoding UTF8

Write-Host "Request JSON written to:"
Write-Host "  $REQUEST_JSON"

# ----------------------------------------------------------------------
# Optional network diagnostics
# ---------------------------------------------------------------------
Write-Section "Network diagnostics"

Test-EndpointNetwork -Uri $embeddingsUri

# ---------------------------------------------------------------------
# Get token/key and invoke endpoint
# ---------------------------------------------------------------------
Write-Section "Invoking embeddings endpoint"

$endpointKey = Get-AmlEndpointKey `
  -ResourceGroup $RESOURCE_GROUP `
  -WorkspaceName $WORKSPACE_NAME `
  -EndpointName $ENDPOINT_NAME

$headers = @{
  "Authorization" = "Bearer $endpointKey"
  "Content-Type"  = "application/json"
}

Write-Host "POST $embeddingsUri"
Write-Host "Authorization: Bearer ___token___"
Write-Host "Content-Type: application/json"

try {
  $response = Invoke-RestMethod `
    -Method Post `
    -Uri $embeddingsUri `
    -Headers $headers `
    -Body $payloadJson `
    -TimeoutSec 300

  $responseJson = $response | ConvertTo-Json -Depth 100
  $responseJson | Set-Content -Path $RESPONSE_JSON -Encoding UTF8

  Write-Host ""
  Write-Host "Response JSON written to:"
  Write-Host "  $RESPONSE_JSON"

  Write-Host ""
  Write-Host "Response preview:"
  $responseJson

  # Convenience: print embedding vector dimensions if response follows OpenAI-like format.
  if ($null -ne $response.data -and $response.data.Count -gt 0 -and $null -ne $response.data[0].embedding) {
    $dim = $response.data[0].embedding.Count
    Write-Host ""
    Write-Host "Embedding dimension detected: $dim"
  }
}
catch {
  Write-Host ""
  Write-Host "Invocation failed." -ForegroundColor Red

  if ($_.Exception.Response) {
    $statusCode = [int]$_.Exception.Response.StatusCode
    Write-Host "HTTP status code: $statusCode" -ForegroundColor Yellow

    try {
      $stream = $_.Exception.Response.GetResponseStream()
      if ($null -ne $stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($errorBody)) {
          Write-Host ""
          Write-Host "Error response body:"
          Write-Host $errorBody
        }
      }
    }
    catch {
      Write-Host "Could not read error response body."
    }
  }
  else {
    Write-Host $_.Exception.Message -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "Common checks:" -ForegroundColor Cyan
  Write-Host "  1. If endpoint PNA is disabled, run from VPN/private network with correct private DNS resolution."
  Write-Host "  2. Confirm the URL route is really /embeddings for this OSS deployment."
  Write-Host "  3. Confirm endpoint auth_mode is key if using endpoint key as Bearer token."
  Write-Host "  4. Confirm deployment is Succeeded and has traffic assigned, or call the route expected by this model server."
  Write-Host "  5. If model expects a different request schema, adjust the JSON payload."

  throw
}

Write-Section "Done"
Write-Host "Endpoint name   : $ENDPOINT_NAME"
Write-Host "Deployment name : $DEPLOYMENT_NAME"
Write-Host "Embeddings URI  : $embeddingsUri"
Write-Host "Request file    : $REQUEST_JSON"
Write-Host "Response file   : $RESPONSE_JSON"