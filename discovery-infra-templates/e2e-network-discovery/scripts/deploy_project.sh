#!/usr/bin/env bash
set -euo pipefail

# <parameters>
# provide the discovery resource subscription id
SUB_ID="69----------------------------------------03"
# provide the RG of discovery resource
DISCOVERY_RG="rg-uks8discovery"
# </parameters>

az account set --subscription "$SUB_ID"

az deployment group create \
  --name "discovery-stage3-project" \
  --resource-group "$DISCOVERY_RG" \
  --template-file project.bicep \
  --parameters project.bicepparam

