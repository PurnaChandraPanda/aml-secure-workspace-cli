#!/usr/bin/env bash
set -euo pipefail


# <parameters>
# provide the discovery resource subscription id
SUB_ID="69----------------------------------------03"
# provide the location of discovery resource
LOCATION="uksouth"
# </parameters>


az account set --subscription "$SUB_ID"

az deployment sub create \
  --name "discovery-e2e-hardened-${LOCATION}" \
  --location "$LOCATION" \
  --template-file main.bicep \
  --parameters main_3.bicepparam

