##-----------------------------------------------------------------------------
# Standard Tagging Module – Applies standard tags to all resources for traceability
##-----------------------------------------------------------------------------
module "labels" {
  source          = "terraform-az-modules/tags/azure"
  version         = "1.0.0"
  name            = var.custom_name == null ? var.name : var.custom_name
  location        = var.location
  environment     = var.environment
  managedby       = var.managedby
  label_order     = var.label_order
  repository      = var.repository
  deployment_mode = var.deployment_mode
  extra_tags      = var.extra_tags
}

##-----------------------------------------------------------------------------
# Key Vault -  Create a Key Vault in the specified resource group
##-----------------------------------------------------------------------------
resource "azurerm_key_vault" "key_vault" {
  count                           = var.enabled ? 1 : 0
  name                            = format(var.resource_position_prefix ? "kv-%s" : "%s-kv", local.name)
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

  dynamic "access_policy" {
    for_each = var.enable_access_policies ? var.access_policies : {}
    content {
      tenant_id               = access_policy.value.tenant_id != null ? access_policy.value.tenant_id : data.azurerm_client_config.current_client_config.tenant_id
      object_id               = access_policy.value.object_id
      application_id          = access_policy.value.application_id
      key_permissions         = access_policy.value.key_permissions
      secret_permissions      = access_policy.value.secret_permissions
      certificate_permissions = access_policy.value.certificate_permissions
      storage_permissions     = access_policy.value.storage_permissions
    }
  }
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

##-----------------------------------------------------------------------------
# Key Vault Secrets - Create secrets in the Key Vault
##-----------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "secrets" {
  depends_on      = [azurerm_role_assignment.rbac_keyvault_administrator]
  for_each        = { for secret in var.secrets : secret.name => secret }
  key_vault_id    = azurerm_key_vault.key_vault[0].id
  name            = each.value.name
  value           = each.value.value
  content_type    = each.value.content_type
  not_before_date = each.value.not_before_date
  expiration_date = each.value.expiration_date != null ? each.value.expiration_date : "2034-10-22T18:29:59Z"
}

##-----------------------------------------------------------------------------
# Private Endpoint - Create a private endpoint for the Key Vault
##-----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "pep" {
  count               = var.enabled && var.enable_private_endpoint ? 1 : 0
  name                = format(var.resource_position_prefix ? "pe-kv-%s" : "%s-pe-kv", local.name)
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = module.labels.tags
  private_dns_zone_group {
    name                 = format(var.resource_position_prefix ? "kv-dns-zone-group-%s" : "%s-kv-dns-zone-group", local.name)
    private_dns_zone_ids = [var.private_dns_zone_ids]
  }
  private_service_connection {
    name                           = format(var.resource_position_prefix ? "psc-kv-%s" : "%s-psc-kv", local.name)
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
# Diagnostic Settings - Configure diagnostic settings for Key Vault
##-----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "az_monitor_diag" {
  depends_on                     = [azurerm_key_vault.key_vault]
  count                          = var.enabled && var.diagnostic_setting_enable ? 1 : 0
  name                           = format(var.resource_position_prefix ? "key-vault-diagnostic-log-%s" : "%s-key-vault-diagnostic-log", local.name)
  target_resource_id             = azurerm_key_vault.key_vault[0].id
  storage_account_id             = var.storage_account_id
  eventhub_name                  = var.eventhub_name
  eventhub_authorization_rule_id = var.eventhub_authorization_rule_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = var.log_analytics_destination_type
  dynamic "enabled_metric" {
    for_each = var.metric_enabled ? ["AllMetrics"] : []
    content {
      category = enabled_metric.value
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

##-----------------------------------------------------------------------------
# Diagnostic Settings - Configure diagnostic settings for Private Endpoint Network Interface
##-----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "pe_kv_nic" {
  depends_on                     = [azurerm_private_endpoint.pep, azurerm_key_vault.key_vault]
  count                          = var.enabled && var.diagnostic_setting_enable && var.enable_private_endpoint ? 1 : 0
  name                           = format(var.resource_position_prefix ? "pe-kv-nic-diagnostic-log-%s" : "%s-pe-kv-nic-diagnostic-log", local.name)
  storage_account_id             = var.storage_account_id
  target_resource_id             = azurerm_private_endpoint.pep[count.index].network_interface[0].id
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

##-----------------------------------------------------------------------------
# Key Vault Managed Hardware Security Module - Create a Key Vault Managed HSM
##-----------------------------------------------------------------------------
resource "azurerm_key_vault_managed_hardware_security_module" "keyvault_hsm" {
  count                         = var.enabled && var.managed_hardware_security_module_enabled ? 1 : 0
  name                          = format(var.resource_position_prefix ? "hsm-kv-%s" : "%s-hsm-kv", local.name)
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
