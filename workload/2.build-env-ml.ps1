## Set the Azure resource details
$RESOURCE_GROUP="" # Set your Azure ML workspace resource group name; e.g. rg-privateaml092
$WORKSPACE_NAME="" # Set your Azure ML workspace name; e.g. mlworkspaces10092
$env_asset_file = "environment\mcr-image-conda.yml" # Path to the environment asset file
# $env_asset_file = "environment\acr-image-conda.yml"
$env_asset_name = "test-env00001" # Name of the environment asset
# $env_asset_name = "test-env00002"

# --- build a composite hash of the env YAML + its conda_file (if any) ----
$envHash = (Get-FileHash -Path $env_asset_file -Algorithm SHA256).Hash.ToLower()

# try to extract 1st "conda_file: ..." line from the YAML
$match = Select-String -Path $env_asset_file -Pattern '^\s*conda_file\s*:\s*(.+)$' `
          | Select-Object -First 1

if ($match) {
    $condaPath = $match.Matches[0].Groups[1].Value.Trim()

    # make the path relative to the env YAML if needed
    if (-not (Test-Path $condaPath)) {
        $condaPath = Join-Path -Path (Split-Path $env_asset_file -Parent) -ChildPath $condaPath
    }

    if (Test-Path $condaPath) {
        $condaHash = (Get-FileHash -Path $condaPath -Algorithm SHA256).Hash.ToLower()
        # combine both hashes; simple and deterministic
        $specHash = "${envHash}:${condaHash}"
    } else {
        Write-Warning "conda_file '$condaPath' referenced but not found - using env YAML hash only"
        $specHash = $envHash
    }
} else {
    # env spec has no external conda_file
    $specHash = $envHash
}

Write-Host "Combined spec hash = $specHash"

# --- get hash tag from latest version (if any) --------------------------
$latestHash = az ml environment show `
                --name  $env_asset_name `
                --label latest `
                --workspace-name $WORKSPACE_NAME `
                --resource-group $RESOURCE_GROUP `
                --query "tags.specHash" -o tsv 2>$null

if ($LASTEXITCODE -eq 0 -and $latestHash -and ($specHash -ieq $latestHash)) {
    Write-Host "Environment spec unchanged - no new version needed."
    exit 0
}

Write-Host "Spec changed (or env absent) - creating a new version."

# work out next version -------------------------------------------------------
$latestVer = az ml environment show `
               --name $env_asset_name `
               --label latest `
               --workspace-name $WORKSPACE_NAME `
               --resource-group $RESOURCE_GROUP `
               --query version -o tsv 2>$null

if ($LASTEXITCODE -eq 0) {
    $version = ([int]$latestVer) + 1
} else {
    $version = 1
}

# create the environment; this call blocks until the build is complete --------
## write the hash of the spec file to the tags
az ml environment create `
     --file  $env_asset_file `
     --name  $env_asset_name `
     --version $version `
     --workspace-name $WORKSPACE_NAME `
     --resource-group  $RESOURCE_GROUP `
     --tags specHash=$specHash `
     -o none           # no --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "Environment $env_asset_name/$version created (specHash=$specHash)"
} else {
    Write-Host "Environment $env_asset_name/$version create failed"
    exit 1
}

Write-Host "Environment $env_asset_name/$version is in running state"

## Check in jobs -> [prepare_image] experiment, i.e. whether any new job has been created
## Wait until the most-recent prepare_image job reaches a terminal state
$terminal = @('Completed','Failed','Canceled')

do {
    Start-Sleep -Seconds 10

    # JMESPath to get the newest prepare_image job status
    $query = '[?experiment_name==`prepare_image`] | sort_by(@,&creation_context.created_at)[-1].status'

    # newest prepare_image job -> last element after sorting by creation time
    $status = az ml job list `
                --workspace-name $WORKSPACE_NAME `
                --resource-group $RESOURCE_GROUP `
                --query $query -o tsv

    if (-not $status) { $status = 'NotFound' }
    Write-Host "prepare_image job status = $status"
} while ($terminal -notcontains $status)

if ($status -eq 'Completed') {
    Write-Host "prepare_image job succeeded"

    ## Sleep for a few seconds to propagate status of env build job
    Start-Sleep -Seconds 5

    Write-Host "Environment $env_asset_name/$version is in **Succeeded** state"
} else {
    Write-Host "prepare_image job ended with status $status"

    ## Sleep for a few seconds to propagate status of env build job
    Start-Sleep -Seconds 5

    Write-Host "Environment $env_asset_name/$version is in **Failed** state"
}

Write-Host "Now, environment asset build activity is over - **ready** for consumption"
## --- end of script -------------------------------------------------------------