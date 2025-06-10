output "id" {
  value       = module.vault[*].id
  description = "The ID of the Key Vault."
}

output "vault_uri" {
  value       = module.vault[*].vault_uri
  description = "value of the Key Vault URI."
}
