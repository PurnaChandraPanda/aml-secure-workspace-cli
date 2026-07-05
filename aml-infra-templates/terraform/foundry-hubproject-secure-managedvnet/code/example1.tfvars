#####
### create all from scratch (expects RGs to exist)
#####
location = "eastus2"
prefix   = "hubsec"

network_resource_group_name = "rg-pupanda1-vnet"
resource_group_name         = "rg-pupanda1"

vnet_address_space               = ["10.50.0.0/16"]
private_endpoint_subnet_prefixes = ["10.50.10.0/24"]

aml_managed_network_isolation_mode = "AllowOnlyApprovedOutbound"

tags = {
  workload    = "foundry_ai_hubproject"
  environment = "dev"
  owner       = "purna"
  managed_by  = "terraform"
}