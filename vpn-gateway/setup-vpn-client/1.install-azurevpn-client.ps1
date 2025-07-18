Write-Host "Installing Azure VPN Client on Windows PC..."

# -------------------------------------------------------------------
# Set subscription and resource details
# -------------------------------------------------------------------
$SUBSCRIPTION_ID="" # Subscription ID for Azure resources
$TENANT_ID="" # Tenant ID for Azure AD authentication
$VNET_RESOURCE_GROUP="" # Resource Group where the VNet; e.g. rg-foundry2wus00012
$VPN_GATEWAY_NAME="" # Name of the VPN Gateway; e.g. vpn-gateway-vnets
$P2S_PROFILE_PATH=".\p2s-profile.zip" # Path to store the P2S profile zip file
$P2S_PROFILE_DESTINATION=".\p2s-profile" # Destination folder for extracted profile files
$AZURE_VPN_P2S_PROFILE_PATH = ".\p2s-profile\AzureVPN\azurevpnconfig.xml" # Path to the Azure VPN Client profile file

# Set the subscription context
az login --tenant $TENANT_ID
az account set --subscription $SUBSCRIPTION_ID

Write-Host "Generating VPN client profile…"
$PROFILE_URL=az network vnet-gateway vpn-client generate `
                --resource-group        $VNET_RESOURCE_GROUP `
                --name                  $VPN_GATEWAY_NAME `
                --authentication-method EAPTLS `
                -o tsv

Write-Host "Downloading profile from $PROFILE_URL …"
Invoke-WebRequest -Uri $PROFILE_URL `
  -OutFile $P2S_PROFILE_PATH `
  -UseBasicParsing

# Extract the profile files
Expand-Archive -Path $P2S_PROFILE_PATH `
    -DestinationPath $P2S_PROFILE_DESTINATION `
    -Force

Write-Host "P2S profile downloaded and extracted to $P2S_PROFILE_DESTINATION."

# Install Azure VPN Client if not already installed
if (-not (Get-Command "AzureVPN" -ErrorAction SilentlyContinue)) {
    Write-Host "Azure VPN Client not found. Installing..."
    # Download and install the Azure VPN Client
    $installerUrl = "https://aka.ms/azurevpnclient"
    $installerPath = "./AzureVPNClient.msi"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet" -Wait
    Write-Host "Azure VPN Client installed."
} else {
    Write-Host "Azure VPN Client is already installed."
}

# Import the VPN client profile
if (-not (Test-Path $AZURE_VPN_P2S_PROFILE_PATH -PathType Leaf)) {
    Write-Host "Profile file not found at $AZURE_VPN_P2S_PROFILE_PATH. Please check the extraction."

} else {
    Write-Host "Importing VPN client profile from $AZURE_VPN_P2S_PROFILE_PATH"
    # locate the actual Azure VPN Client executable
    try {
        $exe = (Get-Command AzureVPN -ErrorAction Stop).Source
    } catch {
        Write-Error "Could not find 'AzureVPN' command. Is Azure VPN Client installed?"
        return
    }

    Write-Host "Importing profile using Azure VPN Client executable at $exe"
}

# Dynamically find the Azure VPN UWP package folder
$package = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory |
    Where-Object Name -like 'Microsoft.AzureVpn_*' |
    Select-Object -First 1
if (-not $package) {
    Write-Error "Azure VPN Client package not found under $env:LOCALAPPDATA\Packages"
    return
}

# Copy the VPN config to the LocalState folder of the Azure VPN Client package
$localStatePath = Join-Path $package.FullName 'LocalState'
Write-Host "Copying VPN config to $localStatePath"
Copy-Item $AZURE_VPN_P2S_PROFILE_PATH (Join-Path $localStatePath 'azurevpnconfig.xml') -Force

Push-Location $localStatePath
try {
    Write-Host "Running Azure VPN import..."
    & $exe -i 'azurevpnconfig.xml' -f
    Write-Host "Profile imported successfully."
} catch {
    Write-Error "Failed to import profile: $_"
} finally {
    Pop-Location
}

Write-Host "Azure VPN Client setup completed. You can now connect to the VPN using the Azure VPN Client application."

# Read its private endpoint connection > Find the private IP address with FQDNs
# Use this IP address to connect to the service via VPN
Write-Host "To connect to the service, use the private IP address obtained from the private endpoint connection of the azure resources."
Write-Host "Ensure you have the necessary permissions to access the private endpoint and that your VPN connection is active."
Write-Host "Run **2.get-pe-privateip-fqdns.ps1** to fetch the private IP and FQDNs for the resources in the specified resource group." 
