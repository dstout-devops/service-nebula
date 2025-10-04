# Output from Init Submodule

output "init_complete" {
  description = "Indicates initialization is complete"
  value       = true
  depends_on  = [null_resource.vault_unseal, null_resource.vault_ha_join]
}

output "credentials_location" {
  description = "Location of Vault credentials"
  value       = "Credentials stored in: /tmp/vault-credentials and secret/${var.unseal_keys_secret_name}"
}
