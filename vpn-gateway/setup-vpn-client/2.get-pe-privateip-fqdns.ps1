Write-Host "Azure VPN Client setup completed. You can now connect to the VPN using the Azure VPN Client application."

# -------------------------------------------------------------------
# Private Endpoint IP & FQDN mappings for various resource types
# -------------------------------------------------------------------
$ResourceGroup = "" # Resource group containing the resources of type Foundry or ML; e.g. rg-foundry2wus00012
$types = @(
  "Microsoft.CognitiveServices/accounts",
  "Microsoft.CognitiveServices/accounts/projects",
  "Microsoft.DocumentDB/databaseAccounts",
  "Microsoft.Search/searchServices",
  "Microsoft.Storage/storageAccounts",
  "Microsoft.MachineLearningServices/workspaces",
  "Microsoft.KeyVault/vaults",
  "microsoft.containerregistry/registries",
  "microsoft.insights/components"
)

# Initialize an empty collection to hold results
$results = @()

# Loop through each resource type and fetch private endpoint connections
foreach ($type in $types) {
    Write-Host "`n==== Resource type: $type ===="
    $resources = az resource list `
                    --resource-group $ResourceGroup `
                    --resource-type $type `
                    --query "[].id" -o tsv

    if (-not $resources) {
        Write-Host "No resources of type $type found in resource group $ResourceGroup."
        continue
    }

    foreach ($res in $resources) {
        Write-Host "`n-- Resource: $res"

        $pecs = az network private-endpoint-connection list `
                    --id $res `
                    --query "[]" -o json | ConvertFrom-Json

        if (-not $pecs) {
            Write-Host "    (no private endpoint connections)"
            continue
        }

        foreach ($pec in $pecs) {
            # Write-Host "    Connection: $($pec.name)"
            $endpointId = $pec.properties.privateEndpoint.id

            # Get the network interface IDs from the private endpoint
            $nicIds = az network private-endpoint show `
                        --ids $endpointId `
                        --query "networkInterfaces[].id" -o tsv

            foreach ($nicId in $nicIds) {
                # Query the NIC for its IP configs (private IP + DNS FQDNs)
                $ipConfigs = az network nic show `
                                --ids $nicId `
                                --query "ipConfigurations[].{IP:privateIPAddress, FQDNs:privateLinkConnectionProperties.fqdns}" `
                                -o json | ConvertFrom-Json

                foreach ($cfg in $ipConfigs) {
                    # Only add if this NicId+IP combo is not already in $results
                    if ($results | Where-Object { $_.NicId -eq $nicId -and $_.IP -eq $cfg.IP })
                    {
                        # Write-Host "    (duplicate entry, skipping)"
                        continue
                    }

                    # Add the unique entry to results
                    $results += [pscustomobject]@{
                        NicId        = $nicId
                        IP           = $cfg.IP
                        FQDNs        = ($cfg.FQDNs -join ',')
                    }
                }
            }
        }
    }
}

# After all loops, print the table of collected entries
if ($results.Count -gt 0) {
    Write-Host "`nCollected Private Endpoint IP & FQDN mappings:`n"
    # Print with a tab between IP and FQDNs
    foreach ($entry in $results) {
        Write-Host "$($entry.IP)`t$($entry.FQDNs)"
    }
} else {
    Write-Host "No Private Endpoint IP or FQDN entries found."
}

Write-Host "Add the private IP and FQDNs to your local **hosts** file or DNS server as needed."
Write-Host "Local hosts file can be found at: C:\Windows\System32\drivers\etc\hosts."
