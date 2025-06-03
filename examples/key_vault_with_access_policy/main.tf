provider "azurerm" {
  features {}
}

provider "azurerm" {
  features {}
  alias = "peer"
}

data "azurerm_client_config" "current_client_config" {}


module "resource_group" {
  source  = "clouddrove/resource-group/azure"
  version = "1.0.2"

  name        = "app"
  environment = "test"
  label_order = ["environment", "name", ]
  location    = "Canada Central"
}

module "vnet" {
  source  = "clouddrove/vnet/azure"
  version = "1.0.4"

  name                = "app"
  environment         = "test"
  label_order         = ["name", "environment"]
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  address_spaces      = ["10.30.0.0/16"]
}

module "subnet" {
  source  = "clouddrove/subnet/azure"
  version = "1.2.1"

  name                 = "app"
  environment          = "test"
  label_order          = ["name", "environment"]
  resource_group_name  = module.resource_group.resource_group_name
  location             = module.resource_group.resource_group_location
  virtual_network_name = module.vnet.vnet_name


  #subnet
  subnet_names    = ["subnet1", "subnet2"]
  subnet_prefixes = ["10.30.1.0/24", "10.30.2.0/24"]

  # route_table
  routes = [
    {
      name           = "rt-test"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "Internet"
    }
  ]
}

module "log-analytics" {
  source                           = "clouddrove/log-analytics/azure"
  version                          = "2.0.0"
  name                             = "app"
  environment                      = "test"
  label_order                      = ["name", "environment"]
  create_log_analytics_workspace   = true
  log_analytics_workspace_sku      = "PerGB2018"
  log_analytics_workspace_id       = module.log-analytics.workspace_id
  resource_group_name              = module.resource_group.resource_group_name
  log_analytics_workspace_location = module.resource_group.resource_group_location
}

module "private-dns-zone" {
  source              = "git::https://github.com/ravimalvia10/private-dns-zone.git?ref=feat/private-dns-zone"
  resource_group_name = module.resource_group.resource_group_name
  private_dns_config = [
    {
      resource_type = "key_vault"
      vnet_ids      = [module.vnet.vnet_id]
    },
  ]
}

#Key Vault
module "vault" {
  source = "../.."

  providers = {
    azurerm.dns_sub  = azurerm.peer, #change this to other alias if dns hosted in other subscription.
    azurerm.main_sub = azurerm
  }

  name                      = "annkdep"
  environment               = "test"
  label_order               = ["name", "environment", ]
  resource_group_name       = module.resource_group.resource_group_name
  location                  = module.resource_group.resource_group_location
  reader_objects_ids        = [data.azurerm_client_config.current_client_config.object_id] # for access policy only use reader or admin
  admin_objects_ids         = [data.azurerm_client_config.current_client_config.object_id] # for access policy only use reader or admin
  subnet_id                 = module.subnet.default_subnet_id[0]
  enable_rbac_authorization = false
  private_dns_zone_ids      = module.private-dns-zone.private_dns_zone_ids.key_vault
  network_acls = {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["1.2.3.4/32"]
  }
  enable_private_endpoint    = true
  diagnostic_setting_enable  = true
  log_analytics_workspace_id = module.log-analytics.workspace_id ## when diagnostic_setting_enable enable,add log analytics workspace id
}
