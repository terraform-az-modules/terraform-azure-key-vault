##-----------------------------------------------------------------------------
## Data block to query information 
##-----------------------------------------------------------------------------
data "azurerm_client_config" "current_client_config" {}

##----------------------------------------------------------------------------- 
## Data block to retreive private ip of private endpoint.
# ##-----------------------------------------------------------------------------
# data "azurerm_private_endpoint_connection" "private-ip" {
#   provider = azurerm.main_sub
#   count    = var.enabled && var.enable_private_endpoint ? 1 : 0

#   name                = azurerm_private_endpoint.pep[0].name
#   resource_group_name = var.resource_group_name
#   depends_on          = [azurerm_key_vault.key_vault]
# }