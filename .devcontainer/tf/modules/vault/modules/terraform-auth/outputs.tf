output "auth_backend_path" {
  description = "Path to the Kubernetes auth backend"
  value       = var.enabled && var.create_auth_backend ? vault_auth_backend.kubernetes[0].path : var.kubernetes_auth_path
}

output "service_account_name" {
  description = "Name of the Terraform service account"
  value       = var.enabled ? kubernetes_service_account.terraform[0].metadata[0].name : null
}

output "service_account_namespace" {
  description = "Namespace of the Terraform service account"
  value       = var.enabled ? kubernetes_service_account.terraform[0].metadata[0].namespace : null
}

output "role_name" {
  description = "Name of the Vault Kubernetes auth role"
  value       = var.enabled ? vault_kubernetes_auth_backend_role.terraform[0].role_name : null
}

output "policy_name" {
  description = "Name of the Vault policy for Terraform"
  value       = var.enabled ? vault_policy.terraform[0].name : null
}
