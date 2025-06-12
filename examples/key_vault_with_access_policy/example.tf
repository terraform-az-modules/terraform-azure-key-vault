provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current_client_config" {}

module "resource_group" {
  source      = "terraform-az-modules/resource-group/azure"
  version     = "1.0.0"
  name        = "app"
  environment = "test"
  label_order = ["environment", "name", ]
  location    = "Canada Central"
}

module "vnet" {
  source              = "terraform-az-modules/vnet/azure"
  version             = "1.0.0"
  name                = "app"
  environment         = "test"
  label_order         = ["name", "environment"]
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  address_spaces      = ["10.0.0.0/16"]
}

module "subnet" {
  source               = "terraform-az-modules/subnet/azure"
  version              = "1.0.0"
  environment          = "test"
  label_order          = ["name", "environment", ]
  resource_group_name  = module.resource_group.resource_group_name
  location             = module.resource_group.resource_group_location
  virtual_network_name = module.vnet.vnet_name
  subnets = [
    {
      name            = "subnet1"
      subnet_prefixes = ["10.0.1.0/24"]
    }
  ]
  enable_route_table = true
  route_tables = [
    {
      name = "route-table"
      routes = [
        {
          name           = "route-table"
          address_prefix = "0.0.0.0/0"
          next_hop_type  = "Internet"
        }
      ]
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
  source              = "git::https://github.com/terraform-az-modules/terraform-azure-private-dns.git?ref=feat/beta"
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
  location                      = module.resource_group.resource_group_location # for access policy only use reader or admin
  subnet_id                     = module.subnet.subnet_ids["subnet1"]
  enable_rbac_authorization     = false
  private_dns_zone_ids          = module.private-dns-zone.private_dns_zone_ids.key_vault
  public_network_access_enabled = true
  enable_access_policies        = true
  access_policies = {
    "app-server" = {
      tenant_id               = data.azurerm_client_config.current_client_config.tenant_id,
      object_id               = data.azurerm_client_config.current_client_config.object_id,
      key_permissions         = ["Get", "List"]
      secret_permissions      = ["Get", "List"]
      certificate_permissions = ["Get", "List"]
      storage_permissions     = []
    },
    "admin-server" = {
      tenant_id               = data.azurerm_client_config.current_client_config.tenant_id,
      object_id               = data.azurerm_client_config.current_client_config.object_id,
      key_permissions         = ["Get", "List", "Create", "Delete", "Purge", "Recover", "Backup", "Restore"]
      secret_permissions      = ["Get", "List", "Set", "Delete", "Purge", "Recover", "Backup"]
      certificate_permissions = ["Get", "List", "Create", "Delete", "Purge", "Recover"]
    },
  }
  diagnostic_setting_enable  = true
  log_analytics_workspace_id = module.log-analytics.workspace_id ## when diagnostic_setting_enable enable,add log analytics workspace id
}
