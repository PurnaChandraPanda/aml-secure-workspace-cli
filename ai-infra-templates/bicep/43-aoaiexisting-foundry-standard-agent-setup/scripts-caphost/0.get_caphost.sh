
#!/usr/bin/env bash
set -euo pipefail

## <set parameters>
SUBSCRIPTION_ID="6977-------------2103" # Set the subscription ID of foundry account
FOUNDRY_RG="rg-stdfoundry41"  # Set the resource group of foundry account, e.g. rg-stdfoundry
FOUNDRY_ACCOUNT="foundry596qua6" # Set the name of foundry account, e.g. aifoundry1231
FOUNDRY_PROJECT="project596qua6"   # Set the name of foundry project, e.g. project1231
API_VERSION="2025-09-01"      # Set the API version to use, e.g. 2025-09-01
## </set parameters>

BASE="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT/projects/$FOUNDRY_PROJECT"
# BASE="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$FOUNDRY_RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCOUNT"

CAPHOSTS_URL="$BASE/capabilityHosts?api-version=$API_VERSION"

echo "== Listing existing project capability hosts =="
caphosts_json=$(az rest --method get --url "$CAPHOSTS_URL" -o json)
echo "$caphosts_json"

