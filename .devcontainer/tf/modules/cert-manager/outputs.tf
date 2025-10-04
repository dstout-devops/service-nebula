# cert-manager Module Outputs

output "namespace" {
  description = "Namespace where cert-manager is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.cert_manager.name
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.cert_manager.status
}

output "chart_version" {
  description = "Version of the cert-manager Helm chart deployed"
  value       = helm_release.cert_manager.version
}

output "controller_replicas" {
  description = "Number of controller replicas"
  value       = var.controller.replicas
}

output "webhook_replicas" {
  description = "Number of webhook replicas"
  value       = var.webhook.replicas
}

output "cainjector_replicas" {
  description = "Number of CA injector replicas"
  value       = var.cainjector.replicas
}

output "crds_enabled" {
  description = "Whether cert-manager CRDs are enabled"
  value       = var.install_crds
}

# Vault Injector TLS Outputs
output "vault_injector_tls_enabled" {
  description = "Whether Vault Agent Injector TLS is enabled"
  value       = var.vault_injector_tls.enabled
}

output "vault_injector_tls_secret_name" {
  description = "Name of the Kubernetes secret containing injector TLS certificates"
  value       = var.vault_injector_tls.enabled ? "injector-tls" : null
}

output "vault_injector_ca_secret_name" {
  description = "Name of the Kubernetes secret containing injector CA certificate"
  value       = var.vault_injector_tls.enabled ? "injector-ca-secret" : null
}

output "vault_injector_webhook_annotation" {
  description = "Annotation to add to Vault injector webhook for CA injection"
  value       = var.vault_injector_tls.enabled ? "cert-manager.io/inject-ca-from: ${var.vault_injector_tls.namespace}/injector-certificate" : null
}
