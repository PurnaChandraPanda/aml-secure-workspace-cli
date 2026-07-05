
####################
# general deployment params (reuse existing network resources)
####################

location = "eastus2"
prefix   = "hubsec"

network_resource_group_name = "rg-pupanda1-vnet"
resource_group_name         = "rg-pupanda5"

aml_managed_network_isolation_mode = "AllowOnlyApprovedOutbound"

tags = {
  workload    = "foundry_ai_hubproject"
  environment = "dev"
  owner       = "purna"
  managed_by  = "terraform"
}

#####################
# use existing vnet/ subnet
######################

create_vnet      = false
existing_vnet_id = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/virtualNetworks/vnet-amlsec-ekg0p3"

create_private_endpoint_subnet      = false
existing_private_endpoint_subnet_id = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/virtualNetworks/vnet-amlsec-ekg0p3/subnets/subnet2"

#############################
# use existing dns zones
#############################

create_private_dns_zone_vnet_links = false

existing_private_dns_zone_ids = {
  aml_api       = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms"
  aml_notebooks = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net"
  storage_blob  = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
  storage_file  = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
  key_vault     = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
  acr           = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
  monitor       = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.monitor.azure.com"
  oms           = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.oms.opinsights.azure.com"
  ods           = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.ods.opinsights.azure.com"
  agentsvc      = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1-vnet/providers/Microsoft.Network/privateDnsZones/privatelink.agentsvc.azure-automation.net"
}

#####
## for ampls
#####
create_ampls_private_endpoint = false
existing_ampls_id             = "/subscriptions/75-------------------------86/resourceGroups/rg-pupanda1/providers/Microsoft.Insights/privateLinkScopes/ampls-amlsec-ekg0p3"
