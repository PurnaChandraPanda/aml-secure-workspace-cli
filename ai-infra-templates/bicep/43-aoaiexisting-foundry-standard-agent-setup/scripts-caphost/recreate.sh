
#!/usr/bin/env bash
set -euo pipefail

##
# Since updates aren't supported for capability hosts, follow this sequence for configuration changes:
# - Delete the existing capability host at project level
# - Wait for deletion to complete
# - Create a new capability host at project level with the desired configuration
##

## <set parameters>
SUBSCRIPTION_ID="697-------------------------103" # Set the subscription ID of foundry account
FOUNDRY_RG="rg-stdfoundry"  # Set the resource group of foundry account, e.g. rg-stdfoundry
FOUNDRY_ACCOUNT="aifoundry1231" # Set the name of foundry account, e.g. aifoundry1231
FOUNDRY_PROJECT="project1231"   # Set the name of foundry project, e.g. project1231
API_VERSION="2025-09-01"      # Set the API version to use, e.g. 2025-09-01
AOAI_CONN='["existing31-aoai"]' # Set the only one AI service connection to use, e.g. ["existing31-aoai"]
## </set parameters>

## <set variables>
BASE="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT/projects/$FOUNDRY_PROJECT"
CAPHOSTS_URL="$BASE/capabilityHosts?api-version=$API_VERSION"
## </set variables>

#####
## HELPERS
#####

# Check for required commands
need_cmd() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: Required command '$1' not found. Please install it." >&2
    exit 1
  fi
}

######
### MAIN
######

# Check for required commands
need_cmd az
need_cmd jq

echo "== Using subscription: $SUBSCRIPTION_ID =="
# Not strictly required, but helps if user is in wrong subscription
az account set --subscription "$SUBSCRIPTION_ID" --only-show-errors >/dev/null 2>&1 || true

echo "== Listing existing PROJECT capability hosts =="
existing_caphost_json=$(az rest --method get --url "$CAPHOSTS_URL" -o json)
echo "$existing_caphost_json"

count="$(echo "$existing_caphost_json" | jq -r '.value | length')"
if [ "$count" -eq 0 ]; then
  echo "No existing capability hosts found at project level. Exiting."
  exit 0
fi
echo "== Fetching existing caphost details (for clone/recreate) =="
# echo "$existing_caphost_json"

echo "== Existing caphost key fields =="
existing_caphost_values=$(echo "$existing_caphost_json" | jq '{
  name: .value[0].name,
  capabilityHostKind: (.value[0].properties.capabilityHostKind),
  aiServicesConnections: (.value[0].properties.aiServicesConnections),
  storageConnections: (.value[0].properties.storageConnections),
  threadStorageConnections: (.value[0].properties.threadStorageConnections),
  vectorStoreConnections: (.value[0].properties.vectorStoreConnections),
  provisioningState: (.value[0].properties.provisioningState)
}')

caphost_provisioning_state=$(echo "$existing_caphost_values" | jq -r '.provisioningState')

if [ "$caphost_provisioning_state" != "Succeeded" ]; then
  echo "Existing capability host is not in 'Succeeded' state. Exiting."
  exit 1
fi

## Print current caphost values
echo ">> Existing capability host values: "
echo ">>"
# echo "$existing_caphost_values"
caphost_name=$(echo "$existing_caphost_values" | jq -r '.name')
caphost_kind=$(echo "$existing_caphost_values" | jq -r '.capabilityHostKind')
# Get connection values for arrays
caphost_ai_services_connections=$(echo "$existing_caphost_values" | jq -c '.aiServicesConnections')
caphost_storage_connections=$(echo "$existing_caphost_values" | jq -c '.storageConnections')
caphost_thread_storage_connections=$(echo "$existing_caphost_values" | jq -c '.threadStorageConnections')
caphost_vector_store_connections=$(echo "$existing_caphost_values" | jq -c '.vectorStoreConnections')
echo "caphost_name: " $caphost_name
echo "caphost_kind: " $caphost_kind
echo "caphost_ai_services_connections: " $caphost_ai_services_connections
echo "caphost_storage_connections: " $caphost_storage_connections
echo "caphost_thread_storage_connections: " $caphost_thread_storage_connections
echo "caphost_vector_store_connections: " $caphost_vector_store_connections

# 1) Prepare caphost URL
CAPHOST_URL="$BASE/capabilityHosts/$caphost_name?api-version=$API_VERSION"
echo "caphost URL: $CAPHOST_URL"

# 2) Delete existing caphost
echo "== Deleting existing capability host: $caphost_name =="
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

# 3) Re-create caphost with same configuration
echo "== Creating new capability host: $caphost_name =="
CAPHOST_URL="$BASE/capabilityHosts/$caphost_name?api-version=$API_VERSION"

# Create caphost with desired configuration
# Check if caphost is created successfully or still in provisioning state
az rest --method put --url "$CAPHOST_URL" --headers "Content-Type=application/json" --only-show-errors --output json \
  --body @- <<EOF
{
  "properties": {
    "capabilityHostKind": "$caphost_kind",
    "threadStorageConnections": $caphost_thread_storage_connections,
    "vectorStoreConnections": $caphost_vector_store_connections,
    "storageConnections": $caphost_storage_connections,
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

echo "== Capability host '$caphost_name' recreation completed successfully. =="

