variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Short lowercase prefix used for resource names. Example: amlsecure"
  type        = string
  default     = "amlsecure"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.prefix))
    error_message = "prefix must be 3-12 chars, lowercase letters and numbers only."
  }
}

variable "network_resource_group_name" {
  description = "Resource group for VNet, private endpoints, and private DNS zones."
  type        = string
  default     = "rg-aml-network"
}

variable "resource_group_name" {
  description = "Resource group for AML workspace and dependent resources."
  type        = string
  default     = "rg-aml-platform"
}

variable "vnet_address_space" {
  description = "Address space for the customer-managed VNet."
  type        = list(string)
  default     = ["10.50.0.0/16"]
}

variable "private_endpoint_subnet_prefixes" {
  description = "Subnet prefixes for private endpoints."
  type        = list(string)
  default     = ["10.50.10.0/24"]
}

variable "aml_managed_network_isolation_mode" {
  description = "Azure ML managed VNet outbound mode. Allowed values: AllowInternetOutbound or AllowOnlyApprovedOutbound."
  type        = string
  default     = "AllowOnlyApprovedOutbound"

  validation {
    condition = contains([
      "AllowInternetOutbound",
      "AllowOnlyApprovedOutbound"
    ], var.aml_managed_network_isolation_mode)

    error_message = "aml_managed_network_isolation_mode must be AllowInternetOutbound or AllowOnlyApprovedOutbound."
  }
}

variable "storage_replication_type" {
  description = "Storage account replication type."
  type        = string
  default     = "LRS"
}

variable "acr_sku" {
  description = "ACR SKU. Premium is required for private endpoint support."
  type        = string
  default     = "Premium"

  validation {
    condition     = var.acr_sku == "Premium"
    error_message = "ACR SKU must be Premium for private endpoint support."
  }
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default = {
    workload    = "azureml"
    environment = "dev"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------
# Existing network support
# ---------------------------------------------------------------------

variable "create_vnet" {
  description = "Whether Terraform should create the VNet. Set false to use an existing VNet."
  type        = bool
  default     = true
}

variable "existing_vnet_id" {
  description = "Existing VNet resource ID. Required when create_vnet=false unless existing_private_endpoint_subnet_id is provided."
  type        = string
  default     = null
}

variable "create_private_endpoint_subnet" {
  description = "Whether Terraform should create the private endpoint subnet. Set false to use an existing subnet."
  type        = bool
  default     = true
}

variable "existing_private_endpoint_subnet_id" {
  description = "Existing subnet resource ID for private endpoints. Required when create_private_endpoint_subnet=false."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------
# Existing Private DNS zone support
# Pass IDs only for zones you want to reuse.
# If a key is missing, Terraform creates that DNS zone.
# ---------------------------------------------------------------------

variable "existing_private_dns_zone_ids" {
  description = <<EOT
Map of existing Private DNS zone IDs to reuse.

Supported keys:
- aml_api
- aml_notebooks
- storage_blob
- storage_file
- key_vault
- acr
- monitor
- oms
- ods
- agentsvc

Example:
existing_private_dns_zone_ids = {
  storage_blob = "/subscriptions/xxx/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
  key_vault    = "/subscriptions/xxx/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
}
EOT

  type    = map(string)
  default = {}
}

variable "create_private_dns_zone_vnet_links" {
  description = "Whether Terraform should create VNet links for Private DNS zones. Set false if links already exist and are not managed by this state."
  type        = bool
  default     = true
}

##############
# For AMPLS private endpoint scope
##############

variable "create_ampls_private_endpoint" {
  description = "Whether Terraform should create a private endpoint for Azure Monitor Private Link Scope. Set false if this VNet already has an AMPLS private endpoint."
  type        = bool
  default     = true
}

variable "existing_ampls_id" {
  description = "Existing Azure Monitor Private Link Scope resource ID to reuse. If null, Terraform creates a new AMPLS."
  type        = string
  default     = null
}
