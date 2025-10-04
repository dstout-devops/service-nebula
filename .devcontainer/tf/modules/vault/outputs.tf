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
  value       = local.is_tls_enabled ? module.tls.k8s_secret_name : null
}

output "root_ca_cert_pem" {
  description = "Root CA certificate in PEM format"
  value       = local.is_tls_enabled ? module.tls.root_ca_cert_pem : null
  sensitive   = false
}

output "intermediate_ca_cert_pem" {
  description = "Intermediate CA certificate in PEM format"
  value       = local.is_tls_enabled ? module.tls.intermediate_ca_cert_pem : null
  sensitive   = false
}

output "ca_chain_pem" {
  description = "Full CA chain (intermediate + root) in PEM format for TLS verification"
  value       = local.is_tls_enabled ? module.tls.ca_chain_pem : null
  sensitive   = false
}

output "vault_server_cert_pem" {
  description = "Vault server certificate in PEM format"
  value       = local.is_tls_enabled ? module.tls.server_cert_pem : null
  sensitive   = false
}

# CA secret not needed - cert-manager uses Vault PKI API directly
# See cert_manager_* outputs below for PKI integration details

# Service Outputs
output "service_name" {
  description = "Name of the main Vault service"
  value       = var.service_name
}

output "internal_service_name" {
  description = "Name of the internal Vault service for HA communication"
  value       = var.internal_service_name
}

output "ui_service_name" {
  description = "Name of the Vault UI service"
  value       = var.ui_service_name
}

output "active_service_name" {
  description = "Name of the Vault active service"
  value       = var.active_service_name
}

output "standby_service_name" {
  description = "Name of the Vault standby service"
  value       = var.standby_service_name
}

# Endpoint Outputs
output "vault_internal_addr" {
  description = "Internal Vault server address for HA communication"
  value       = local.is_tls_enabled ? "https://${var.internal_service_name}:8200" : "http://${var.internal_service_name}:8200"
}

output "vault_ui_addr" {
  description = "Vault UI address"
  value       = local.is_tls_enabled ? "https://${var.ui_service_name}.${var.namespace}.svc.cluster.local:8200" : "http://${var.ui_service_name}.${var.namespace}.svc.cluster.local:8200"
}

# Configuration Outputs
output "replicas" {
  description = "Number of Vault replicas"
  value       = local.is_ha ? var.ha_replicas : 1
}

output "storage_size" {
  description = "Size of persistent storage for each Vault pod"
  value       = var.storage.size
}

output "storage_class" {
  description = "Storage class used for Vault data"
  value       = var.storage.class
}

# Unseal Keys Output
output "unseal_keys_secret_name" {
  description = "Name of the Kubernetes secret containing unseal keys"
  value       = var.unseal_keys_secret_name
}

# Pod Selector
output "pod_selector" {
  description = "Label selector for Vault pods"
  value       = "app.kubernetes.io/name=vault,app.kubernetes.io/instance=${helm_release.vault.name}"
}

# Helm Chart Info
output "chart_version" {
  description = "Version of the Vault Helm chart deployed"
  value       = helm_release.vault.version
}

output "chart_values" {
  description = "Computed Helm values for the deployment"
  value       = helm_release.vault.values
  sensitive   = true
}

# Injector Configuration
output "injector_enabled" {
  description = "Whether Vault Agent Injector is enabled"
  value       = var.injector.enabled
}

output "injector_replicas" {
  description = "Number of Vault Agent Injector replicas"
  value       = var.injector.replicas
}

output "injector_uses_cert_manager" {
  description = "Whether Vault Agent Injector uses cert-manager for TLS"
  value       = var.injector.use_cert_manager
}

output "injector_tls_secret_name" {
  description = "Name of the TLS secret for Vault Agent Injector"
  value       = var.injector.use_cert_manager ? var.injector.tls_secret_name : null
}

# PKI Secrets Engine Outputs
output "pki_engine_enabled" {
  description = "Whether PKI secrets engine is enabled"
  value       = var.pki_engine.enabled
}

output "pki_mount_path" {
  description = "Vault PKI mount path"
  value       = var.pki_engine.enabled ? module.pki_engine.mount_path : null
}

output "pki_mount_accessor" {
  description = "Vault PKI mount accessor ID"
  value       = var.pki_engine.enabled ? module.pki_engine.mount_accessor : null
}

output "pki_root_ca_certificate" {
  description = "PKI Root CA certificate in PEM format"
  value       = var.pki_engine.enabled ? module.pki_engine.root_ca_certificate : null
  sensitive   = false
}

output "pki_root_ca_issuer_id" {
  description = "PKI Root CA issuer ID"
  value       = var.pki_engine.enabled ? module.pki_engine.root_ca_issuer_id : null
}

output "pki_role_name" {
  description = "PKI role name for cert-manager"
  value       = var.pki_engine.enabled ? module.pki_engine.role_name : null
}

output "pki_sign_path" {
  description = "Vault path for signing certificates"
  value       = var.pki_engine.enabled ? module.pki_engine.sign_path : null
}

output "pki_issue_path" {
  description = "Vault path for issuing certificates"
  value       = var.pki_engine.enabled ? module.pki_engine.issue_path : null
}

output "pki_kubernetes_auth_path" {
  description = "Kubernetes auth backend path for PKI"
  value       = var.pki_engine.enabled ? module.pki_engine.kubernetes_auth_path : null
}

output "pki_kubernetes_auth_role" {
  description = "Kubernetes auth role name for cert-manager"
  value       = var.pki_engine.enabled ? module.pki_engine.kubernetes_auth_role_name : null
}

output "pki_policy_name" {
  description = "Vault policy name for cert-manager PKI access"
  value       = var.pki_engine.enabled ? module.pki_engine.policy_name : null
}
