output "id" {
  value = try(azurerm_key_vault.key_vault[0].id, null)
  description = "value of the Key Vault ID"
}

output "vault_uri" {
  value = try(azurerm_key_vault.key_vault[0].vault_uri, null)
  description = "value of the Key Vault URI"
}
