##-----------------------------------------------------------------------------
# Standard Tagging Module – Applies standard tags to all resources for traceability
##-----------------------------------------------------------------------------
module "labels" {
  source          = "terraform-az-modules/tags/azure"
  version         = "1.0.0"
  name            = var.custom_name == "" ? var.name : var.custom_name
  location        = var.location
  environment     = var.environment
  managedby       = var.managedby
  label_order     = var.label_order
  repository      = var.repository
  deployment_mode = var.deployment_mode
  extra_tags      = var.extra_tags
}

##-----------------------------------------------------------------------------
## Key Vault Resource -  Creates a Key Vault in the specified resource group
##-----------------------------------------------------------------------------
resource "azurerm_key_vault" "key_vault" {
  count = var.enabled ? 1 : 0

  provider                        = azurerm.main_sub
  name                            = format(var.resource_position_prefix ? "nsg-%s" : "%s-nsg", local.name)
  location                        = var.location
  resource_group_name             = var.resource_group_name
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  tenant_id                       = data.azurerm_client_config.current_client_config.tenant_id
  purge_protection_enabled        = var.purge_protection_enabled
  soft_delete_retention_days      = var.soft_delete_retention_days
  enable_rbac_authorization       = var.enable_rbac_authorization
  public_network_access_enabled   = var.public_network_access_enabled
  sku_name                        = var.sku_name
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_template_deployment = var.enabled_for_template_deployment
  tags                            = module.labels.tags

  dynamic "network_acls" {
    for_each = var.network_acls == null ? [] : [var.network_acls]
    iterator = acl
    content {
      bypass                     = acl.value.bypass
      default_action             = acl.value.default_action
      ip_rules                   = acl.value.ip_rules
      virtual_network_subnet_ids = acl.value.virtual_network_subnet_ids
    }
  }

  dynamic "contact" {
    for_each = var.certificate_contacts
    content {
      email = contact.value.email
      name  = contact.value.name
      phone = contact.value.phone
    }
  }

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

##-----------------------------------------------------------------------------
## key vault secret resource -  Creates a Key Vault secret in the specified key vault
##-----------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "key_vault_secret" {
  for_each     = var.secrets
  key_vault_id = azurerm_key_vault.key_vault[0].id
  name         = each.key
  value        = each.value
}
##-----------------------------------------------------------------------------
# key
##-----------------------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "readers_policy" {
  provider = azurerm.main_sub
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? [] : var.reader_objects_ids)

  object_id    = each.value
  tenant_id    = data.azurerm_client_config.current_client_config.tenant_id
  key_vault_id = azurerm_key_vault.key_vault[0].id

  key_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]

  certificate_permissions = [
    "Get",
    "List",
  ]
}

resource "azurerm_key_vault_access_policy" "admin_policy" {
  provider = azurerm.main_sub
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? [] : var.admin_objects_ids)

  object_id    = each.value
  tenant_id    = data.azurerm_client_config.current_client_config.tenant_id
  key_vault_id = azurerm_key_vault.key_vault[0].id

  key_permissions = [
    "Backup",
    "Create",
    "Decrypt",
    "Delete",
    "Encrypt",
    "Get",
    "Import",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Sign",
    "UnwrapKey",
    "Update",
    "Verify",
    "WrapKey",
    "Rotate",
    "GetRotationPolicy",
    "SetRotationPolicy",
    "Release"
  ]

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
  ]

  certificate_permissions = [
    "Backup",
    "Create",
    "Delete",
    "DeleteIssuers",
    "Get",
    "GetIssuers",
    "Import",
    "List",
    "ListIssuers",
    "ManageContacts",
    "ManageIssuers",
    "Purge",
    "Recover",
    "Restore",
    "SetIssuers",
    "Update",
  ]
}

##-----------------------------------------------------------------------------
## Below resource will provide user access on key vault based on role base access in azure environment.
## if rbac is enabled then below resource will create. 
##-----------------------------------------------------------------------------
resource "azurerm_role_assignment" "rbac_keyvault_administrator" {
  provider = azurerm.main_sub
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? var.admin_objects_ids : [])

  scope                = azurerm_key_vault.key_vault[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "rbac_keyvault_secrets_users" {
  provider = azurerm.main_sub
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? var.reader_objects_ids : [])

  scope                = azurerm_key_vault.key_vault[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "rbac_keyvault_reader" {
  provider = azurerm.main_sub
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? var.reader_objects_ids : [])

  scope                = azurerm_key_vault.key_vault[0].id
  role_definition_name = "Key Vault Reader"
  principal_id         = each.value
}

##-----------------------------------------------------------------------------
##Below resource will deploy private endpoint for key vault.
##-----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "pep" {
  provider = azurerm.main_sub
  count    = var.enabled && var.enable_private_endpoint ? 1 : 0

  name                = format("%s-pe-kv", module.labels.id)
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = module.labels.tags

  private_dns_zone_group {
    name                 = format("%s-kv-dns-zone-group", module.labels.id)
    private_dns_zone_ids = [var.private_dns_zone_ids]

  }

  private_service_connection {
    name                           = format("%s-psc-kv", module.labels.id)
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.key_vault[0].id
    subresource_names              = ["vault"]
  }
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

##----------------------------------------------------------------------------- 
## Below resources will create diagnostic setting for key vault and its components. 
##-----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "az_monitor_diag" {
  provider = azurerm.main_sub
  count    = var.enabled && var.diagnostic_setting_enable ? 1 : 0

  name                           = format("%s-Key-vault-diagnostic-log", module.labels.id)
  target_resource_id             = azurerm_key_vault.key_vault[0].id
  storage_account_id             = var.storage_account_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = var.eventhub_authorization_rule_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = var.log_analytics_destination_type
  dynamic "metric" {
    for_each = var.metric_enabled ? ["AllMetrics"] : []
    content {
      category = metric.value
      enabled  = true
    }
  }
  dynamic "enabled_log" {
    for_each = var.kv_logs.enabled ? var.kv_logs.category != null ? var.kv_logs.category : var.kv_logs.category_group : []
    content {
      category       = var.kv_logs.category != null ? enabled_log.value : null
      category_group = var.kv_logs.category == null ? enabled_log.value : null
    }
  }
  lifecycle {
    ignore_changes = [log_analytics_destination_type]
  }
}

resource "azurerm_monitor_diagnostic_setting" "pe_kv_nic" {
  provider   = azurerm.main_sub
  depends_on = [azurerm_private_endpoint.pep]
  count      = var.enabled && var.diagnostic_setting_enable && var.enable_private_endpoint ? 1 : 0

  name                           = format("%s-pe-kv-nic-diagnostic-log", module.labels.id)
  target_resource_id             = azurerm_private_endpoint.pep[count.index].network_interface[0].id
  storage_account_id             = var.storage_account_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = var.eventhub_authorization_rule_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = var.log_analytics_destination_type
  dynamic "metric" {
    for_each = var.metric_enabled ? ["AllMetrics"] : []
    content {
      category = metric.value
      enabled  = true
    }
  }
  lifecycle {
    ignore_changes = [log_analytics_destination_type]
  }
}

resource "azurerm_key_vault_managed_hardware_security_module" "keyvault_hsm" {
  provider = azurerm.main_sub
  count    = var.enabled && var.managed_hardware_security_module_enabled ? 1 : 0

  name                          = format("%s-hsm-kv", module.labels.id)
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.sku_name_hsm
  tenant_id                     = data.azurerm_client_config.current_client_config.tenant_id
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  admin_object_ids              = var.admin_objects_ids
  public_network_access_enabled = var.public_network_access_enabled

  dynamic "network_acls" {
    for_each = var.network_acls == null ? [] : [var.network_acls]
    iterator = acl
    content {
      bypass         = acl.value.bypass
      default_action = acl.value.default_action
    }
  }

  tags = module.labels.tags
}
