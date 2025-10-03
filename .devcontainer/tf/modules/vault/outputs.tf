# Vault Module Outputs

output "namespace" {
  description = "Namespace where Vault is deployed"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.vault.name
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.vault.status
}

output "vault_addr" {
  description = "Vault server address"
  value       = local.is_tls_enabled ? "https://vault.${var.namespace}.svc.cluster.local:8200" : "http://vault.${var.namespace}.svc.cluster.local:8200"
}

output "vault_service_name" {
  description = "Kubernetes service name for Vault"
  value       = "vault"
}

output "is_ha_mode" {
  description = "Whether Vault is deployed in HA mode"
  value       = local.is_ha
}

output "is_tls_enabled" {
  description = "Whether TLS is enabled for Vault"
  value       = local.is_tls_enabled
}

output "deployment_mode" {
  description = "Current deployment mode"
  value       = var.deployment_mode
}

output "pki_secret_name" {
  description = "Name of the Kubernetes secret containing PKI certificates"
  value       = local.is_tls_enabled ? var.tls_secret_name : null
}

output "pki_directory" {
  description = "Directory containing all PKI materials"
  value       = local.is_tls_enabled ? local.pki_dir : null
}
