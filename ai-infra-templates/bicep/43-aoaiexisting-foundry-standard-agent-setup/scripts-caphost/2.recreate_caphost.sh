
## <set parameters>
SUBSCRIPTION_ID="6977----------------------2103" # Set the subscription ID of foundry account
FOUNDRY_RG="rg-stdfoundry"  # Set the resource group of foundry account, e.g. rg-stdfoundry
FOUNDRY_ACCOUNT="aifoundry1231" # Set the name of foundry account, e.g. aifoundry1231
FOUNDRY_PROJECT="project1231"   # Set the name of foundry project, e.g. project1231
API_VERSION="2025-09-01"      # Set the API version to use, e.g. 2025-09-01
AOAI_CONN='["existing31-aoai"]' # Set the only one AI service connection to use, e.g. ["existing31-aoai"]
## </set parameters>

COSMOS_CONN='["aifoundry1231cosmosdb"]' # Set the only one Cosmos DB connection to use, e.g. ["aifoundry1231cosmosdb"]
SEARCH_CONN='["aifoundry1231search"]'   # Set the only one Search connection to use, e.g. ["aifoundry1231search"]
STORAGE_CONN='["aifoundry1231storage"]' # Set the only one Storage connection to use, e.g. ["aifoundry1231storage"]


BASE="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT/projects/$FOUNDRY_PROJECT"
caphost_name="caphostproj"

echo "== Creating new capability host: $caphost_name =="
CAPHOST_URL="$BASE/capabilityHosts/$caphost_name?api-version=$API_VERSION"

# Create caphost with desired configuration
# Check if caphost is created successfully or still in provisioning state
az rest --method put --url "$CAPHOST_URL" --only-show-errors --output json \
  --body @- <<EOF
{
  "properties": {
    "capabilityHostKind": "Agents",
    "threadStorageConnections": $COSMOS_CONN,
    "vectorStoreConnections": $SEARCH_CONN,
    "storageConnections": $STORAGE_CONN,
    "aiServicesConnections": $AOAI_CONN
  }
}
EOF

echo "== Capability host create request is submitted: $caphost_name =="

# Optionally wait for creation to complete
while true; do
    echo "Checking provisioning state of capability host '$caphost_name'..."

    provisioning_state=$(az rest --method get --url "$CAPHOST_URL" --only-show-errors -o json | jq -r '.properties.provisioningState')

    echo "Current provisioning state: $provisioning_state"

    if [ "$provisioning_state" == "Succeeded" ]; then
        echo "Capability host '$caphost_name' created successfully."
        break
    elif [ "$provisioning_state" == "Failed" ]; then
        echo "ERROR: Capability host '$caphost_name' creation failed."
        exit 1
    else
        echo "Capability host '$caphost_name' is still in provisioning state '$provisioning_state'. Waiting..."
    fi

    sleep 10
done