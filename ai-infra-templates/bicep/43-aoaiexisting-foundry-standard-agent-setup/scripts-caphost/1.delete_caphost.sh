
## <set parameters>
SUBSCRIPTION_ID="697---------------------103" # Set the subscription ID of foundry account
FOUNDRY_RG="rg-stdfoundry"  # Set the resource group of foundry account, e.g. rg-stdfoundry
FOUNDRY_ACCOUNT="aifoundry1231" # Set the name of foundry account, e.g. aifoundry1231
FOUNDRY_PROJECT="project1231"   # Set the name of foundry project, e.g. project1231
API_VERSION="2025-09-01"      # Set the API version to use, e.g. 2025-09-01
## </set parameters>


BASE="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT/projects/$FOUNDRY_PROJECT"
caphost_name="caphostproj"

echo "== Deleting existing capability host: $caphost_name =="
CAPHOST_URL="$BASE/capabilityHosts/$caphost_name?api-version=$API_VERSION"

az rest --method delete --url "$CAPHOST_URL" -o none --only-show-errors || true

# wait for delete completion; check for GET until 404/NotFound returned
# also, add a conditional check for provisioningState
echo "== wait for deletion to complete =="

while true; do
    if az rest --method get --url "$CAPHOST_URL" -o none --only-show-errors 2>/dev/null; then
        echo "Capability host '$caphost_name' still exists. Waiting..."
    else
        echo "Capability host '$caphost_name' deleted."
        break
    fi

    sleep 10
done

