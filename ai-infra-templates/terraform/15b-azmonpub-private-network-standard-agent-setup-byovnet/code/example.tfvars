resource_group_name_resources = "rg-sw1251"
resource_group_name_dns       = "wg-swc1vnt"
subnet_id_agent               = "/subscriptions/69-------------------------------03/resourceGroups/wg-swc1vnt/providers/Microsoft.Network/virtualNetworks/vnet1232swc/subnets/default5"
subnet_id_private_endpoint    = "/subscriptions/69-------------------------------03/resourceGroups/wg-swc1vnt/providers/Microsoft.Network/virtualNetworks/vnet1232swc/subnets/default"
subscription_id_resources     = "69-------------------------------03"
subscription_id_infra         = "69-------------------------------03"
location                      = "swedencentral"

# Use public Azure Monitor endpoints for Application Insights and Log Analytics.
# When true, AMPLS and the Azure Monitor private endpoint are not deployed.
enable_public_monitoring_access = true
