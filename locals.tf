
##-----------------------------------------------------------------------------
## Locals declaration for determining the local variables
##-----------------------------------------------------------------------------
locals {
  name = var.custom_name != "" ? var.custom_name : module.labels.id
  # valid_rg_name = var.existing_private_dns_zone == null ? var.resource_group_name : var.existing_private_dns_zone_resource_group_name
  # private_dns_zone_name = var.enable_private_endpoint ? var.existing_private_dns_zone == null ? azurerm_private_dns_zone.dnszone[0].name : var.existing_private_dns_zone : null
}
