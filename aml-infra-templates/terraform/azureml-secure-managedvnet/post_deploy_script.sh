#!/usr/bin/env bash
set -euo pipefail

# <parameters>
SUBSCRIPTION_ID="75-------------------------86"
RESOURCE_GROUP="rg-pupanda4"
WORKSPACE_NAME="mlw-amlsec-um9arj"
# </parameters>

az account set --subscription "$SUBSCRIPTION_ID"

# Ensure latest Azure ML CLI extension.
az extension add --name ml --yes >/dev/null 2>&1 || true
az extension update --name ml >/dev/null 2>&1 || true

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