#!/usr/bin/env bash

set -euo pipefail

# tenant id
export TENANT_ID="16-------------------------------d3"
# subscription id
export SUBSCRIPTION_ID="69---------------------------------03"
# resource group where ml workspace is in
export ML_RESOURCE_GROUP="rg-mlws"
# ml workspace name
export ML_WORKSPACE="mlws01"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
JOB_FILE="helloworld-job.yml"

cd "$SCRIPT_DIR"

if [ ! -f "$JOB_FILE" ]; then
    echo "ERROR: Job definition '$SCRIPT_DIR/$JOB_FILE' was not found." >&2
    exit 1
fi

if ! az extension show --name ml &>/dev/null; then
    echo "ERROR: Azure CLI extension 'ml' is not installed. Run: az extension add --name ml" >&2
    exit 1
fi

az login --tenant "$TENANT_ID"
az account set --subscription "$SUBSCRIPTION_ID"

echo "Submitting '$JOB_FILE' to workspace '$ML_WORKSPACE'..."
az ml job create \
    --file "$JOB_FILE" \
    --resource-group "$ML_RESOURCE_GROUP" \
    --workspace-name "$ML_WORKSPACE" \
    --stream