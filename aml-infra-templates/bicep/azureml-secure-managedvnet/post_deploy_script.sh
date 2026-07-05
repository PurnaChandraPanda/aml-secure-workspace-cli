#!/usr/bin/env bash
set -euo pipefail

# <parameters>
SUBSCRIPTION_ID="75-------------------------86"
RESOURCE_GROUP="rg-pupanda6"
WORKSPACE_NAME="mlw-amlsec-34kp6g63usyga" # ml workspace name
# </parameters>

az account set --subscription "$SUBSCRIPTION_ID"

echo "☑️☑️ adding network outbound rules ..."

# Add FQDN outbound rule for PyPI.
az ml workspace outbound-rule set \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --rule "out-fqdn-pypi" \
  --type fqdn \
  --destination "pypi.org"

# Add FQDN outbound rule for Azure Blob wildcard.
az ml workspace outbound-rule set \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --rule "out-fqdn-blob-core-windows-net" \
  --type fqdn \
  --destination "*.blob.core.windows.net"

# Verify rules.
az ml workspace outbound-rule list \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --output table

# Provision/re-provision managed network after rule changes.
az ml workspace provision-network \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME"

echo "✅✅ done adding network outbound rules."