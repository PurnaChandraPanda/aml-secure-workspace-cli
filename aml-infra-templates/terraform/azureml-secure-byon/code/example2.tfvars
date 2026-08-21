
####################
# general deployment params (reuse existing network resources)
####################

location = "eastus2"
prefix   = "amlsec"

network_resource_group_name = "rg-pupanda1-vnet"
resource_group_name         = "rg-pupanda4"

tags = {
  workload    = "azureml"
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
}
