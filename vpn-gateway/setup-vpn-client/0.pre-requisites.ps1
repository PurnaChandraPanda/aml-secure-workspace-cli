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
    # fully non-interactive, suppresses all output
    Write-Host "Upgrading Azure CLI…"
    Start-Process -FilePath "az" `
      -ArgumentList @("upgrade","--yes","--all","--only-show-errors","--output","table") `
      -NoNewWindow -Wait `
      -RedirectStandardOutput "$env:TEMP\az-upgrade.log" `
      -RedirectStandardError  "$env:TEMP\az-upgrade-error.log"
    Write-Host "Azure CLI upgrade finished."

    # List az cli version details
    az --version
}

