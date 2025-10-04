# TLS Submodule Outputs
# Exports certificates, keys, and CA bundles for Vault server TLS

# Root CA Outputs
output "root_ca_cert_pem" {
  description = "Root CA certificate in PEM format"
  value       = var.enabled ? tls_self_signed_cert.root_ca[0].cert_pem : null
  sensitive   = false
}

output "root_ca_private_key_pem" {
  description = "Root CA private key in PEM format"
  value       = var.enabled ? tls_private_key.root_ca[0].private_key_pem : null
  sensitive   = true
}

# Intermediate CA Outputs
output "intermediate_ca_cert_pem" {
  description = "Intermediate CA certificate in PEM format"
  value       = var.enabled ? tls_locally_signed_cert.intermediate_ca[0].cert_pem : null
  sensitive   = false
}

output "intermediate_ca_private_key_pem" {
  description = "Intermediate CA private key in PEM format"
  value       = var.enabled ? tls_private_key.intermediate_ca[0].private_key_pem : null
  sensitive   = true
}

# Server Certificate Outputs
output "server_cert_pem" {
  description = "Vault server certificate in PEM format"
  value       = var.enabled ? tls_locally_signed_cert.vault_server[0].cert_pem : null
  sensitive   = false
}

output "server_private_key_pem" {
  description = "Vault server private key in PEM format"
  value       = var.enabled ? tls_private_key.vault_server[0].private_key_pem : null
  sensitive   = true
}

# Combined Outputs
output "ca_chain_pem" {
  description = "Full CA chain (intermediate + root) in PEM format for TLS verification"
  value       = var.enabled ? "${tls_locally_signed_cert.intermediate_ca[0].cert_pem}${tls_self_signed_cert.root_ca[0].cert_pem}" : null
  sensitive   = false
}

# Kubernetes Secret Output
output "k8s_secret_name" {
  description = "Name of the Kubernetes secret containing TLS certificates"
  value       = var.enabled && var.create_k8s_secret ? kubernetes_secret.vault_tls[0].metadata[0].name : null
}
