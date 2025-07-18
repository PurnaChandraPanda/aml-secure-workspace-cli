# Install Azure CLI on Windows only if it is not present
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI not found - installing..."
    $pkg = "$env:TEMP\AzureCLI.msi"
    Invoke-WebRequest -Uri "https://aka.ms/installazurecliwindows" -OutFile $pkg
    Start-Process msiexec.exe -ArgumentList "/i", $pkg, "/qn" -Wait
    Remove-Item $pkg
    Write-Host "Azure CLI installed."
} else {
    Write-Host "Azure CLI already installed - skipping."

    # Check if the Azure CLI is up to date
    az upgrade -y

    # Install ml extension
    az extension add --name ml --upgrade --yes

    # List extensions in az cli
    az extension list -o table

}

