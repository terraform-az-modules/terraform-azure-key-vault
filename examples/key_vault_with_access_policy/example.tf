provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current_client_config" {}


module "resource_group" {
  source  = "terraform-az-modules/resource-group/azure"
  version = "1.0.0"

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
  source                        = "../.."
  name                          = "app"
  environment                   = "test"
  label_order                   = ["name", "environment", "location"]
  resource_group_name           = module.resource_group.resource_group_name
  location                      = module.resource_group.resource_group_location                # for access policy only use reader or admin
  admin_objects_ids             = [data.azurerm_client_config.current_client_config.object_id] # for access policy only use reader or admin
  subnet_id                     = module.subnet.default_subnet_id[0]
  enable_rbac_authorization     = true
  private_dns_zone_ids          = module.private-dns-zone.private_dns_zone_ids.key_vault
  public_network_access_enabled = true
  network_acls = {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["0.0.0.0/0"]
  }

  reader_objects_ids = {
    "key vault Read User" = {
      role_definition_name = "Key Vault Reader"
      principal_id         = data.azurerm_client_config.current_client_config.object_id
    },
    "key vault secerts user" = {
      role_definition_name = "Key Vault Secrets User"
      principal_id         = data.azurerm_client_config.current_client_config.object_id
    }
  }
  secrets = [
    {
      name            = "api-key"
      value           = "1234567890abcdef"
      content_type    = "text/plain"
      not_before_date = null
      expiration_date = null
    }
  ]
  enable_access_policies     = false
  enable_private_endpoint    = true
  diagnostic_setting_enable  = true
  log_analytics_workspace_id = module.log-analytics.workspace_id ## when diagnostic_setting_enable enable,add log analytics workspace id
}
