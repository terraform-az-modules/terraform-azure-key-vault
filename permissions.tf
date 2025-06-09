# ##-----------------------------------------------------------------------------
# # Key Vault Role Assignments - Create role assignments for RBAC
# ##-----------------------------------------------------------------------------
resource "azurerm_role_assignment" "rbac_keyvault_administrator" {
  for_each = toset(var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? var.admin_objects_ids : [])

  scope                = azurerm_key_vault.key_vault[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "rbac_other_keyvault_roles" {
  for_each             = var.enable_rbac_authorization && var.enabled && !var.managed_hardware_security_module_enabled ? var.reader_objects_ids : {}
  scope                = azurerm_key_vault.key_vault[0].id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

