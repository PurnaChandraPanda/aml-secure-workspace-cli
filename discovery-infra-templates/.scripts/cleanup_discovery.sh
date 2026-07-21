#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cleanup_discovery.sh <discovery-rg> <subscription-id>
#   DISCOVERY_RG=<rg> SUB_ID=<sub> ./cleanup_discovery.sh

DISCOVERY_RG="${DISCOVERY_RG:-${1:-}}"
SUB_ID="${SUB_ID:-${2:-}}"

DISCOVERY_API_VERSION="${DISCOVERY_API_VERSION:-2026-06-01}"

DISCOVERY_LAYER_SETTLE_SECONDS="${DISCOVERY_LAYER_SETTLE_SECONDS:-300}"
DISCOVERY_LAYER_POLL_SECONDS="${DISCOVERY_LAYER_POLL_SECONDS:-10}"


if [[ -z "$DISCOVERY_RG" ]]; then
  echo "[ERROR] DISCOVERY_RG required."
  echo "Usage:"
  echo "  ./cleanup_discovery.sh <discovery-rg> <subscription-id>"
  echo "  DISCOVERY_RG=\"rg-uks7discovery\" SUB_ID=\"69--------------------------------------103\" ./cleanup_discovery.sh"
  exit 1
fi

if [[ -n "$SUB_ID" ]]; then
  az account set --subscription "$SUB_ID"
fi

echo
echo "============================================================"
echo " Microsoft Discovery RG cleanup"
echo "============================================================"
echo "Resource group : $DISCOVERY_RG"
if [[ -n "$SUB_ID" ]]; then
  echo "Subscription   : $SUB_ID"
else
  echo "Subscription   : current az account context"
fi
echo "============================================================"
echo

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

log_step() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

rg_exists() {
  az group show --name "$DISCOVERY_RG" --query id -o tsv >/dev/null 2>&1
}

list_ids_by_type() {
  local resource_type="$1"

  az resource list \
    --resource-group "$DISCOVERY_RG" \
    --resource-type "$resource_type" \
    --query "[].id" \
    -o tsv 2>/dev/null || true
}

sort_ids_child_first() {
  # Sort longer IDs first so nested resources are attempted before parents
  # when a type listing includes mixed-depth IDs.
  awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-
}

wait_until_deleted() {
  local id="$1"
  local attempts="${DELETE_WAIT_ATTEMPTS:-60}"
  local sleep_seconds="${DELETE_WAIT_SECONDS:-10}"

  for ((i = 1; i <= attempts; i++)); do
    if ! az resource show --ids "$id" --query id -o tsv >/dev/null 2>&1; then
      echo "[OK] Deleted: $id"
      return 0
    fi

    echo "[INFO] Still visible, waiting before re-check: attempt $i/$attempts"
    sleep "$sleep_seconds"
  done

  echo "[WARN] Resource still visible after wait: $id"
  return 1
}

delete_resource_id() {
  local id="$1"

  [[ -z "$id" ]] && return 0

  echo "[DELETE] $id"

  local delete_output
  local delete_rc=0

  delete_output="$(az resource delete \
    --ids "$id" \
    --only-show-errors \
    -o none 2>&1)" || delete_rc=$?

  if [[ "$delete_rc" -eq 0 ]]; then
    wait_until_deleted "$id"
    return $?
  fi

  echo "[WARN] Delete command returned non-zero for:"
  echo "       $id"
  echo "[WARN] Azure CLI delete output:"
  echo "$delete_output"

  echo "[INFO] Verifying actual resource state after failed delete..."

  if ! az resource show --ids "$id" --query id -o tsv >/dev/null 2>&1; then
    echo "[OK] Resource is gone despite delete command failure: $id"
    return 0
  fi

  echo "[ERROR] Resource is still visible after failed delete:"
  echo "        $id"

  echo "[INFO] Current resource state:"
  az resource show \
    --ids "$id" \
    --query "{name:name,type:type,provisioningState:properties.provisioningState,id:id}" \
    -o table || true

  echo "[INFO] Recent failed activity log entries for this resource group:"
  az monitor activity-log list \
    --resource-group "$DISCOVERY_RG" \
    --status Failed \
    --offset 4h \
    --query "[].{time:eventTimestamp,operation:operationName.value,status:status.value,subStatus:subStatus.value,resourceId:resourceId,message:properties.statusMessage}" \
    -o jsonc || true

  return 1
}

wait_until_types_gone() {
  local label="$1"
  shift

  local resource_types=("$@")
  local max_wait_seconds="${DISCOVERY_LAYER_SETTLE_SECONDS:-120}"
  local poll_seconds="${DISCOVERY_LAYER_POLL_SECONDS:-10}"
  local elapsed=0

  echo "[INFO] Waiting until $label resources are fully cleaned up..."

  while true; do
    local ids=()
    local resource_type
    local id

    for resource_type in "${resource_types[@]}"; do
      while IFS= read -r id; do
        [[ -n "$id" ]] && ids+=("$id")
      done < <(list_ids_by_type "$resource_type")
    done

    if [[ "${#ids[@]}" -eq 0 ]]; then
      echo "[OK] $label fully cleaned up."
      return 0
    fi

    if [[ "$elapsed" -ge "$max_wait_seconds" ]]; then
      echo "[ERROR] $label still has ${#ids[@]} resource(s) after waiting ${max_wait_seconds}s:"
      printf '%s\n' "${ids[@]}"
      return 1
    fi

    echo "[INFO] $label still has ${#ids[@]} resource(s). Rechecking in ${poll_seconds}s..."
    sleep "$poll_seconds"
    elapsed=$((elapsed + poll_seconds))
  done
}

delete_by_types() {
  local label="$1"
  shift

  local resource_types=("$@")
  local ids=()
  local resource_type
  local id

  for resource_type in "${resource_types[@]}"; do
    echo "[INFO] Checking type: $resource_type"

    while IFS= read -r id; do
      [[ -n "$id" ]] && ids+=("$id")
    done < <(list_ids_by_type "$resource_type")
  done

  if [[ "${#ids[@]}" -eq 0 ]]; then
    echo "[SKIP] $label: no matching resources found."
    return 0
  fi

  echo "[INFO] Found ${#ids[@]} resource(s) for: $label"

  while IFS= read -r id; do
    delete_resource_id "$id"
  done < <(printf '%s\n' "${ids[@]}" | sort -u | sort_ids_child_first)

  wait_until_types_gone "$label" "${resource_types[@]}"
}

show_remaining_discovery_resources() {
  log_step "Remaining Microsoft.Discovery resources in $DISCOVERY_RG"

  local remaining_count
  remaining_count="$(az resource list \
    --resource-group "$DISCOVERY_RG" \
    --query "length([?starts_with(type, 'Microsoft.Discovery') || starts_with(type, 'microsoft.discovery')])" \
    -o tsv 2>/dev/null || echo 0)"

  remaining_count="${remaining_count:-0}"

  if [[ "$remaining_count" == "0" ]]; then
    echo "OK: No remaining Microsoft.Discovery resources found in '$DISCOVERY_RG'."
    return 0
  fi

  echo "WARNING: Found $remaining_count remaining Microsoft.Discovery resource(s):"

  az resource list \
    --resource-group "$DISCOVERY_RG" \
    --query "[?starts_with(type, 'Microsoft.Discovery') || starts_with(type, 'microsoft.discovery')].{name:name,type:type,id:id}" \
    -o table || true

  return 1
}

wait_for_no_remaining_discovery_resources() {
  local max_attempts="${DISCOVERY_FINAL_VALIDATE_ATTEMPTS:-24}"
  local sleep_seconds="${DISCOVERY_FINAL_VALIDATE_SLEEP_SECONDS:-5}"

  echo ""
  echo "[INFO] Waiting for Microsoft.Discovery resource list to settle..."

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if show_remaining_discovery_resources; then
      echo "[OK] No remaining Microsoft.Discovery resources after validation attempt $attempt/$max_attempts."
      return 0
    fi

    echo "[INFO] Microsoft.Discovery resources still visible. Re-checking after ${sleep_seconds}s. Attempt $attempt/$max_attempts."
    sleep "$sleep_seconds"
  done

  echo "[WARN] Microsoft.Discovery resources are still visible after final validation attempts."
  return 1
}

DISCOVERY_WORKSPACE_MRGS=()

add_unique_rg() {
  local rg="$1"
  [[ -z "$rg" ]] && return 0

  local existing
  for existing in "${DISCOVERY_WORKSPACE_MRGS[@]:-}"; do
    [[ "$existing" == "$rg" ]] && return 0
  done

  DISCOVERY_WORKSPACE_MRGS+=("$rg")
}

list_discovery_workspace_names() {
  az resource list \
    --resource-group "$DISCOVERY_RG" \
    --resource-type "Microsoft.Discovery/workspaces" \
    --query "[].name" \
    -o tsv 2>/dev/null || true
}

extract_rg_name_from_arm_id() {
  local arm_id="$1"

  echo "$arm_id" | sed -n 's#.*[Rr]esource[Gg]roups/\([^/]*\).*#\1#p'
}

clean_value() {
  # remove windows carriage returns and trim whitespace (usually noticed when copy pasting in terminal)
  printf '%s' "${1:-}" | tr -d '\r' | xargs
}

try_get_mrg_from_workspace_payload() {
  local workspace_name="$1"
  local workspace_id
  local mrg
  local rc

  workspace_name="$(clean_value "$workspace_name")"
  SUB_ID="$(clean_value "$SUB_ID")"
  DISCOVERY_RG="$(clean_value "$DISCOVERY_RG")"
  DISCOVERY_API_VERSION="$(clean_value "$DISCOVERY_API_VERSION")"

  workspace_id="/subscriptions/${SUB_ID}/resourceGroups/${DISCOVERY_RG}/providers/Microsoft.Discovery/workspaces/${workspace_name}"

  echo "[DEBUG] Discovery workspace ARM ID: $workspace_id" >&2
  echo "[DEBUG] Discovery API version: $DISCOVERY_API_VERSION" >&2

  mrg="$(az resource show \
    --ids "$workspace_id" \
    --api-version "$DISCOVERY_API_VERSION" \
    --query "properties.managedResourceGroup" \
    -o tsv 2>/tmp/discovery_mrg_err.txt)"
  rc=$?

  mrg="$(clean_value "$mrg")"

  if [[ "$rc" -ne 0 ]]; then
    echo "[WARN] az resource show failed for workspace: $workspace_name" >&2
    cat /tmp/discovery_mrg_err.txt >&2 || true
    return 1
  fi

  if [[ -n "$mrg" && "$mrg" != "null" && "$mrg" != "None" ]]; then
    printf '%s\n' "$mrg"
    return 0
  fi

  echo "[WARN] properties.managedResourceGroup query returned empty for workspace: $workspace_name" >&2
  return 1
}

find_workspace_mrg_by_rg_name_pattern() {
  local workspace_name="$1"

  # Observed Discovery workspace MRG pattern:
  # mrg-dwsp-<workspace-name>-<suffix>
  az group list \
    --query "[?starts_with(name, 'mrg-dwsp-${workspace_name}-')].name" \
    -o tsv 2>/dev/null || true
}

discover_managed_rgs_for_discovery_workspaces() {
  log_step "Discover managed RGs mapped to Discovery workspace(s)"

  local workspace_name
  local mrg_name

  while IFS= read -r workspace_name; do
    [[ -z "$workspace_name" ]] && continue

    echo "[INFO] Discovery workspace found: $workspace_name"

    mrg_name=""

    if mrg_name="$(try_get_mrg_from_workspace_payload "$workspace_name")"; then
      mrg_name="$(clean_value "$mrg_name")"
    else
      mrg_name=""
    fi

    if [[ -n "$mrg_name" && "$mrg_name" != "null" && "$mrg_name" != "None" ]]; then
      echo "[INFO] Managed RG from properties.managedResourceGroup: $mrg_name"
      add_unique_rg "$mrg_name"
    else
      echo "[WARN] properties.managedResourceGroup not found for workspace: $workspace_name"
    fi

    if [[ -n "$mrg_name" && "$mrg_name" != "null" && "$mrg_name" != "None" ]]; then
      echo "[INFO] Managed RG from properties.managedResourceGroup: $mrg_name"
      add_unique_rg "$mrg_name"
      continue
    fi

    echo "[WARN] properties.managedResourceGroup not found for workspace: $workspace_name"
    echo "[INFO] Trying fallback name-pattern scan..."

    while IFS= read -r mrg_name; do
      [[ -z "$mrg_name" ]] && continue
      echo "[INFO] Managed RG candidate from name pattern: $mrg_name"
      add_unique_rg "$mrg_name"
    done < <(find_workspace_mrg_by_rg_name_pattern "$workspace_name")

  done < <(list_discovery_workspace_names)

  if [[ "${#DISCOVERY_WORKSPACE_MRGS[@]}" -eq 0 ]]; then
    echo "[WARN] No Discovery workspace managed RGs discovered."
    echo "[WARN] If workspace is already deleted, pass explicit FOUNDRY_PURGE_RGS='mrg1,mrg2'."
    return 1
  fi

  echo "[INFO] Final managed RG candidate list:"
  printf '  - %s\n' "${DISCOVERY_WORKSPACE_MRGS[@]}"
}

list_deleted_foundry_account_ids_for_rg() {
  local rg="$1"

  az rest \
    --method get \
    --url "https://management.azure.com/subscriptions/${SUB_ID}/providers/Microsoft.CognitiveServices/deletedAccounts?api-version=2024-10-01" \
    --query "value[?contains(id, '/resourceGroups/${rg}/') && contains(id, '/deletedAccounts/')].id" \
    -o tsv 2>/dev/null || true
}

wait_until_deleted_foundry_account_purged() {
  local deleted_id="$1"
  local max_wait_seconds="${FOUNDRY_PURGE_WAIT_SECONDS:-120}"
  local poll_seconds="${FOUNDRY_PURGE_POLL_SECONDS:-10}"
  local elapsed=0

  echo "[INFO] Waiting for Foundry purge to settle: $deleted_id"

  while true; do
    if ! az rest \
      --method get \
      --url "https://management.azure.com${deleted_id}?api-version=2024-10-01" \
      --query id \
      -o tsv >/dev/null 2>&1; then
      echo "[OK] Soft-deleted Foundry account purged: $deleted_id"
      return 0
    fi

    if [[ "$elapsed" -ge "$max_wait_seconds" ]]; then
      echo "[WARN] Foundry deleted account still visible after purge wait: $deleted_id"
      return 1
    fi

    echo "[INFO] Foundry deleted account still visible. Rechecking in ${poll_seconds}s..."
    sleep "$poll_seconds"
    elapsed=$((elapsed + poll_seconds))
  done
}

purge_deleted_foundry_accounts_for_discovered_mrgs() {
  log_step "Purge soft-deleted Foundry / Azure AI Services accounts from Discovery managed RGs"

  local candidate_rgs=()
  local rg
  local deleted_id
  local deleted_ids=()

  # 1. Use dynamically discovered Discovery workspace MRGs.
  for rg in "${DISCOVERY_WORKSPACE_MRGS[@]:-}"; do
    [[ -n "$rg" ]] && candidate_rgs+=("$rg")
  done

  # 2. Optional manual override/fallback.
  # Example:
  # FOUNDRY_PURGE_RGS="mrg-dwsp-ws1-abc123,mrg-dwsp-ws2-def456" ./cleanup_discovery.sh ...
  if [[ -n "${FOUNDRY_PURGE_RGS:-}" ]]; then
    IFS=',' read -ra explicit_rgs <<< "$FOUNDRY_PURGE_RGS"
    for rg in "${explicit_rgs[@]}"; do
      rg="$(echo "$rg" | xargs)"
      [[ -n "$rg" ]] && candidate_rgs+=("$rg")
    done
  fi

  # 3. Keep DISCOVERY_RG fallback as harmless check.
  candidate_rgs+=("$DISCOVERY_RG")

  for rg in "${candidate_rgs[@]}"; do
    [[ -z "$rg" ]] && continue

    echo "[INFO] Checking soft-deleted Foundry accounts under RG: $rg"

    while IFS= read -r deleted_id; do
      [[ -z "$deleted_id" ]] && continue
      deleted_ids+=("$deleted_id")
    done < <(list_deleted_foundry_account_ids_for_rg "$rg")
  done

  if [[ "${#deleted_ids[@]}" -eq 0 ]]; then
    echo "[SKIP] No soft-deleted Foundry / Azure AI Services accounts found for candidate RGs."
    return 0
  fi

  echo "[INFO] Found ${#deleted_ids[@]} soft-deleted Foundry account(s) to purge."

  for deleted_id in "${deleted_ids[@]}"; do
    echo "[PURGE] $deleted_id"

    if az rest \
      --method delete \
      --url "https://management.azure.com${deleted_id}?api-version=2024-10-01" \
      --only-show-errors \
      -o none; then
      wait_until_deleted_foundry_account_purged "$deleted_id" || true
    else
      echo "[WARN] Purge failed for soft-deleted Foundry account:"
      echo "       $deleted_id"
    fi
  done
}

delete_resource_group_if_empty() {
  local rg="$1"

  echo ""
  echo "-- Resource group delete check: $rg"

  local exists
  exists="$(az group exists --name "$rg" -o tsv 2>/dev/null || echo false)"

  if [[ "$exists" != "true" ]]; then
    echo "OK: Resource group '$rg' does not exist or is already deleted."
    return 0
  fi

  local lock_count
  lock_count="$(az lock list \
    --resource-group "$rg" \
    --query "length(@)" \
    -o tsv 2>/dev/null || echo 0)"

  if [[ "$lock_count" != "0" ]]; then
    echo "ERROR: Resource group '$rg' has lock(s). Skipping RG delete."

    az lock list \
      --resource-group "$rg" \
      --query "[].{name:name,level:level}" \
      -o table || true

    return 1
  fi

  local total_count
  total_count="$(az resource list \
    --resource-group "$rg" \
    --query "length(@)" \
    -o tsv 2>/dev/null || echo 0)"

  if [[ "$total_count" != "0" ]]; then
    echo "WARNING: RG '$rg' still has $total_count resource(s). Skipping RG delete."

    az resource list \
      --resource-group "$rg" \
      --query "[].{name:name,type:type}" \
      -o table || true

    return 1
  fi

  echo "OK: RG '$rg' is empty. Deleting resource group..."

  if az group delete \
    --name "$rg" \
    --yes \
    --no-wait \
    -o none; then

    az group wait --deleted --name "$rg"
    echo "OK: Resource group '$rg' deleted."
    return 0
  fi

  echo "ERROR: Failed to submit resource group delete for '$rg'."
  return 1
}

# ------------------------------------------------------------------------------
# Pre-check
# ------------------------------------------------------------------------------

if ! rg_exists; then
  echo "[DONE] Resource group does not exist: $DISCOVERY_RG"
  exit 0
fi

# Discover mapped MRGs before workspace deletion removes the parent ARM resource.
discover_managed_rgs_for_discovery_workspaces || true

echo "Cleanup sequence:"
echo "  1. Discovery Agents"
echo "  2. Discovery Project"
echo "  3. Discovery ChatDeploymentModel"
echo "  4. Discovery Workspace"
echo "  5. Discovery Tools"
echo "  6. Discovery nodepool"
echo "  7. Discovery supercomputer"
echo "  8. Discovery bookshelf"
echo "  9. Discovery Storage Asset"
echo " 10. Discovery Storage Container"
echo

# ------------------------------------------------------------------------------
# Cleanup sequence
# ------------------------------------------------------------------------------

log_step "1. Discovery Agents"
delete_by_types \
  "Discovery Agents" \
  "Microsoft.Discovery/agents" \
  "Microsoft.Discovery/workspaces/projects/agents"

log_step "2. Discovery Project"
delete_by_types \
  "Discovery Project" \
  "Microsoft.Discovery/workspaces/projects"

log_step "3. Discovery ChatDeploymentModel"
delete_by_types \
  "Discovery ChatDeploymentModel" \
  "Microsoft.Discovery/workspaces/chatModelDeployments"

log_step "4. Discovery Workspace"
delete_by_types \
  "Discovery Workspace" \
  "Microsoft.Discovery/workspaces"

log_step "5. Discovery nodepool"
delete_by_types \
  "Discovery nodepool" \
  "Microsoft.Discovery/supercomputers/nodePools" \
  "Microsoft.Discovery/supercomputers/nodepools"

log_step "6. Discovery supercomputer"
delete_by_types \
  "Discovery supercomputer" \
  "Microsoft.Discovery/supercomputers"

log_step "7. Discovery Tools"
delete_by_types \
  "Discovery Tools" \
  "Microsoft.Discovery/tools" \
  "Microsoft.Discovery/workspaces/projects/tools"

log_step "8. Discovery bookshelf"
delete_by_types \
  "Discovery bookshelf" \
  "Microsoft.Discovery/bookshelves"

log_step "9. Discovery Storage Asset"
delete_by_types \
  "Discovery Storage Asset" \
  "Microsoft.Discovery/storageContainers/storageAssets" \
  "Microsoft.Discovery/storagecontainers/storageassets"

log_step "10. Discovery Storage Container"
delete_by_types \
  "Discovery Storage Container" \
  "Microsoft.Discovery/storageContainers" \
  "Microsoft.Discovery/storagecontainers"

log_step "11. Foundry / Azure AI Services accounts"
delete_by_types \
"Foundry / Azure AI Services accounts" \
"Microsoft.CognitiveServices/accounts"

purge_deleted_foundry_accounts_for_discovered_mrgs "$DISCOVERY_RG"

echo ""
echo "== Final validation =="

if wait_for_no_remaining_discovery_resources; then
  echo ""
  echo "== No remaining Discovery resources. Trying RG delete next =="

  if delete_resource_group_if_empty "$DISCOVERY_RG"; then
    echo "== RG delete step completed successfully =="
  else
    echo "== RG delete step skipped or failed safely =="
    echo "Reason: RG may have locks, non-Discovery resources, or delete submission failed."
  fi
else
  echo ""
  echo "== RG delete skipped =="
  echo "Reason: some Discovery resources are still present."
fi

echo
echo "[DONE] Microsoft Discovery cleanup completed for RG: $DISCOVERY_RG"

