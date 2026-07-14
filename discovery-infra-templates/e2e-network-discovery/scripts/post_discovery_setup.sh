#!/usr/bin/env bash
set -euo pipefail


# <parameters>
# provide resource subscription id
SUB_ID="697-----------------------------03"
# provide discovery workspace RG
RG="rg-swc2discovery"
# provide discovery workspace name
WS="ws-demo-001"
# provide discovery workspace project name
PROJECT="prj-demo-001"
# </parameters>

az account set --subscription "$SUB_ID"

# Microsoft Discovery Platform Administrator (Preview)
# Role ID from Microsoft Discovery RBAC docs
DISCOVERY_PLATFORM_ADMIN_ROLE_ID="7a2b6e6c-472e-4b39-8878-a26eb63d75c6"
RG_SCOPE="/subscriptions/$SUB_ID/resourceGroups/$RG"

echo "== Workspace =="
az resource show \
  --ids "/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Discovery/workspaces/$WS" \
  --query "{name:name, state:properties.provisioningState, publicNetworkAccess:properties.publicNetworkAccess}" \
  -o jsonc

echo "== Projects =="
az resource list \
  --resource-group "$RG" \
  --resource-type "Microsoft.Discovery/workspaces/projects" \
  -o table

USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

echo "== Ensure Discovery Platform Administrator role at RG scope =="
EXISTING_DISCOVERY_ADMIN_COUNT=$(az role assignment list \
  --assignee "$USER_OBJECT_ID" \
  --scope "$RG_SCOPE" \
  --include-inherited \
  --query "[?contains(roleDefinitionId, '$DISCOVERY_PLATFORM_ADMIN_ROLE_ID')] | length(@)" \
  -o tsv)

if [[ "$EXISTING_DISCOVERY_ADMIN_COUNT" == "0" ]]; then
  echo "Role missing. Adding Microsoft Discovery Platform Administrator (Preview) at scope: $RG_SCOPE"

  az role assignment create \
    --assignee-object-id "$USER_OBJECT_ID" \
    --assignee-principal-type User \
    --role "$DISCOVERY_PLATFORM_ADMIN_ROLE_ID" \
    --scope "$RG_SCOPE" \
    --only-show-errors \
    -o table

  echo "Role assignment added."
else
  echo "Role already present or inherited. Skipping role assignment."
fi

echo "== My RBAC at RG =="
az role assignment list \
  --assignee "$USER_OBJECT_ID" \
  --scope "$RG_SCOPE" \
  --include-inherited \
  --query "[].{role:roleDefinitionName, scope:scope}" \
  -o table

echo "== Direct data-plane call =="
TOKEN=$(az account get-access-token --resource "https://discovery.azure.com/" --query accessToken -o tsv)
curl -i \
  -H "Authorization: Bearer $TOKEN" \
  "https://$WS.workspace.discovery.azure.com/projects/$PROJECT/investigations?api-version=2026-06-01"
