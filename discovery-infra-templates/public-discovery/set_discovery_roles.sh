#!/usr/bin/env bash
set -euo pipefail

# <parameters>
# provide the resource subscription id
SUB_ID="697-------------------------------103"
# this is constant as per docs - for entra discovery app registration
DISCOVERY_APP_ID="92c174ac-8e41-4815-a1b7-d81b19ab03ce" 
# </parameters>

SCOPE="/subscriptions/${SUB_ID}"

echo "Using subscription: ${SUB_ID}"
echo "Using Discovery appId: ${DISCOVERY_APP_ID}"
echo "Using scope: ${SCOPE}"
echo

# ===== Set subscription context =====
echo "Setting Azure CLI subscription context..."
az account set --subscription "${SUB_ID}"

echo "Current Azure CLI context:"
az account show \
  --query "{subscription:id, tenant:tenantId, name:name, state:state}" \
  -o table

echo

# ===== Resolve Discovery service principal =====
echo "Resolving Discovery control-plane service principal..."
az ad sp show --id "${DISCOVERY_APP_ID}" \
  --query "{displayName:displayName, objectId:id, appId:appId}" \
  -o table

DISCOVERY_SP_OBJECT_ID="$(az ad sp show --id "${DISCOVERY_APP_ID}" --query id -o tsv)"

if [[ -z "${DISCOVERY_SP_OBJECT_ID}" ]]; then
  echo "ERROR: Could not resolve Discovery service principal object ID."
  exit 1
fi

echo
echo "Discovery service principal objectId: ${DISCOVERY_SP_OBJECT_ID}"
echo

# ===== Function to check and add role if missing =====
ensure_role_assignment() {
  local role_name="$1"

  echo "Checking role: ${role_name}"

  local existing_count
  existing_count="$(az role assignment list \
    --assignee "${DISCOVERY_SP_OBJECT_ID}" \
    --scope "${SCOPE}" \
    --include-inherited \
    --query "[?roleDefinitionName=='${role_name}'] | length(@)" \
    -o tsv)"

  if [[ "${existing_count}" != "0" ]]; then
    echo "Role already present or inherited: ${role_name}"
  else
    echo "Role missing. Adding role assignment: ${role_name}"

    az role assignment create \
      --assignee-object-id "${DISCOVERY_SP_OBJECT_ID}" \
      --assignee-principal-type ServicePrincipal \
      --role "${role_name}" \
      --scope "${SCOPE}" \
      --only-show-errors \
      -o table

    echo "Added role assignment: ${role_name}"
  fi

  echo
}

# ===== Required / substitute roles =====
# Reader is documented for Discovery control-plane service app subscription enumeration.
ensure_role_assignment "Reader"

# Built-in substitute when custom Discovery NSP Perimeter Joiner role cannot be created.
ensure_role_assignment "Network Contributor"

# ===== Final verification =====
echo "Final role assignments for Discovery service principal:"
az role assignment list \
  --assignee "${DISCOVERY_SP_OBJECT_ID}" \
  --scope "${SCOPE}" \
  --include-inherited \
  --query "[].{role:roleDefinitionName, scope:scope}" \
  -o table