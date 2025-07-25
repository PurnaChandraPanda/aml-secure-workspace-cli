#!/bin/bash

set -e
# set -x

# <Start> Set subscription and resource details
SUBSCRIPTION_ID="" # Subscription ID for Azure resources
TENANT_ID="" # Tenant ID for Azure AD authentication
VNET_RESOURCE_GROUP="" # Resource Group where the VNet; e.g. rg-foundry2wus00012
VNET_NAME="" # Name of the Virtual Network; e.g. agent-vnet-test
REGION="" # Azure region where the VNet is located; e.g. westus
VPN_GATEWAY_NAME="" # Name of the VPN Gateway; e.g. vpn-gateway-vnets
PIP_NAME="${VPN_GATEWAY_NAME}-pip" # Name of the Public IP for VPN Gateway
GATEWAY_SUBNET_NAME="GatewaySubnet" # Name of the Gateway Subnet, must be "GatewaySubnet" for Azure VPN Gateway
GATEWAY_SUBNET_ADDRESS_PREFIX="" # Adjust the address prefix as needed - must be /27 or larger; e.g. "192.168.2.0/27"
VPN_CLIENT_POOL_ADDRESS_PREFIX="172.16.0.0/24" # Address pool for VPN clients
P2S_AAD_AUDIENCE="c632b3df-fb67-4d84-bdcf-b95ad541b5c8" # Azure AD Application ID (fixed for Azure VPN client) for VPN client authentication
P2S_AAD_ISSUER="https://sts.windows.net/$TENANT_ID/"
P2S_AAD_TENANT="https://login.microsoftonline.com/$TENANT_ID"
# <End> Set subscription and resource details

# Set the subscription context
az account set --subscription "$SUBSCRIPTION_ID"

# Create a public IP address for vpn gateway. 
## Check if public ip exists, else create it
PIP_RESULT=$(az network public-ip show \
                --resource-group $VNET_RESOURCE_GROUP \
                --name $PIP_NAME \
                --query name -o tsv 2>/dev/null || echo "")

if [ -z "$PIP_RESULT" ]; then
    echo "$PIP_RESULT - public ip does not exist"
    # Create Public IP for VPN Gateway
    az network public-ip create \
      --resource-group $VNET_RESOURCE_GROUP \
      --name $PIP_NAME \
      --location $REGION \
      --sku Standard \
      --allocation-method Static

    # Wait until provisioning completes
    az network public-ip wait \
      --resource-group $VNET_RESOURCE_GROUP \
      --name $PIP_NAME \
      --created

    # Re-query to get the name
    PIP_RESULT=$(az network public-ip show \
                    --name $PIP_NAME \
                    --resource-group $VNET_RESOURCE_GROUP \
                    --query name -o tsv)
    echo "$PIP_RESULT - public ip created"
else
    echo $PIP_RESULT "- public ip exists"
fi

# Check if GatewaySubnet exists, else create it - meant for Azure VPN Gateway
GATEWAY_SUBNET_RESULT=$(az network vnet subnet show \
                          --resource-group $VNET_RESOURCE_GROUP \
                          --vnet-name $VNET_NAME \
                          --name $GATEWAY_SUBNET_NAME \
                          --query "name" \
                          -o tsv 2>/dev/null || echo "")
if [ -z "$GATEWAY_SUBNET_RESULT" ]; then
    echo "$GATEWAY_SUBNET_RESULT - gateway subnet does not exist .. creating it"
    # Create Gateway Subnet
    az network vnet subnet create \
      --resource-group $VNET_RESOURCE_GROUP \
      --vnet-name $VNET_NAME \
      --name $GATEWAY_SUBNET_NAME \
      --address-prefix $GATEWAY_SUBNET_ADDRESS_PREFIX
else
    echo $GATEWAY_SUBNET_RESULT "- gateway subnet exists"
fi

# Check if VPN Gateway exists, else create it
VPN_GATEWAY_RESULT=$(az network vnet-gateway show \
                        --name $VPN_GATEWAY_NAME \
                        --resource-group $VNET_RESOURCE_GROUP \
                        --query "name" \
                        -o tsv 2>/dev/null || echo "")
if [ -z $VPN_GATEWAY_RESULT ]; then
    echo "$VPN_GATEWAY_RESULT - vpn gateway does not exist .. creating it"
    # Create VPN Gateway
    az network vnet-gateway create \
      --resource-group $VNET_RESOURCE_GROUP \
      --name $VPN_GATEWAY_NAME \
      --location $REGION \
      --vnet $VNET_NAME \
      --gateway-type Vpn \
      --public-ip-address $PIP_NAME \
      --vpn-type RouteBased \
      --sku VpnGw1 \
      --no-wait

    # Wait until the vnet Gateway is fully provisioned
    az network vnet-gateway wait \
      --resource-group $VNET_RESOURCE_GROUP \
      --name $VPN_GATEWAY_NAME \
      --created
else
    # Wait until the VPN Gateway is fully provisioned
    # Only wait if the gateway is not already in "Succeeded" state
    CURRENT_STATE=$(az network vnet-gateway show \
                      --resource-group $VNET_RESOURCE_GROUP \
                      --name $VPN_GATEWAY_NAME \
                      --query "provisioningState" \
                      -o tsv)
    if [[ "$CURRENT_STATE" != "Succeeded" ]]; then
      echo "Gateway provisioning state is '$CURRENT_STATE'; waiting for creation to complete…"
      az network vnet-gateway wait \
          --resource-group $VNET_RESOURCE_GROUP \
          --name $VPN_GATEWAY_NAME \
          --created
    fi
      
    echo $VPN_GATEWAY_RESULT "- vnet gateway exists in succeeded state"
fi

# Enable point-to-site VPN on the vnet gateway
## Configure an address pool for your VPN clients
VPN_CLIENT_POOL=$(az network vnet-gateway show \
                            --resource-group $VNET_RESOURCE_GROUP \
                            --name $VPN_GATEWAY_NAME \
                            --query "vpnClientConfiguration.vpnClientAddressPool.addressPrefixes[0]" \
                            -o tsv 2>/dev/null || echo "")

# Only update if the existing pool differs from desired
if [[ "$VPN_CLIENT_POOL" != "$VPN_CLIENT_POOL_ADDRESS_PREFIX" ]]; then
    echo "Updating VPN client pool from '$VPN_CLIENT_POOL' to '$VPN_CLIENT_POOL_ADDRESS_PREFIX'…"

    # Update the VPN client pool address prefix
    # Update for tunnel type OpenVPN (SSL)
    # Update for Azure Active Directory authentication type with tenant/ audience/ issuer details
    az network vnet-gateway update \
      --resource-group $VNET_RESOURCE_GROUP \
      --name $VPN_GATEWAY_NAME \
      --address-prefixes $VPN_CLIENT_POOL_ADDRESS_PREFIX \
      --client-protocol OpenVPN \
      --aad-audience $P2S_AAD_AUDIENCE \
      --aad-issuer $P2S_AAD_ISSUER \
      --aad-tenant $P2S_AAD_TENANT

else
    echo $VPN_CLIENT_POOL "- vpn client point-to-site pool configuration exists"
fi

# echo "Generating VPN client profile…"
# PROFILE_URL=$(az network vnet-gateway vpn-client generate \
#   --resource-group        $VNET_RESOURCE_GROUP \
#   --name                  $VPN_GATEWAY_NAME \
#   --authentication-method EAPTLS \
#   -o tsv)

# echo "Downloading profile from $PROFILE_URL …"
# curl -sSL -o ./p2s-profile.zip "$PROFILE_URL"

# # Extract the profile files
# unzip -d ./p2s-profile ./p2s-profile.zip
# echo "P2S profile in ./p2s-profile/"
