# Outputs for Vault PKI Secrets Engine Submodule

# ============================================================================
# PKI Mount Information
# ============================================================================

output "mount_path" {
  description = "Path where the PKI secrets engine is mounted"
  value       = var.enabled ? vault_mount.pki[0].path : null
}

output "mount_accessor" {
  description = "Accessor ID of the PKI mount"
  value       = var.enabled ? vault_mount.pki[0].accessor : null
}

# ============================================================================
# Root CA Information
# ============================================================================

output "root_ca_certificate" {
  description = "Root CA certificate PEM"
  value       = var.enabled ? vault_pki_secret_backend_root_cert.pki[0].certificate : null
}

output "root_ca_issuer_id" {
  description = "Root CA issuer ID"
  value       = var.enabled ? vault_pki_secret_backend_root_cert.pki[0].issuer_id : null
}

output "root_ca_serial_number" {
  description = "Root CA serial number"
  value       = var.enabled ? vault_pki_secret_backend_root_cert.pki[0].serial_number : null
}

# ============================================================================
# PKI Role Information
# ============================================================================

output "role_name" {
  description = "Name of the PKI role for cert-manager"
  value       = var.enabled ? vault_pki_secret_backend_role.cert_manager[0].name : null
}

output "sign_path" {
  description = "Vault path for signing certificates"
  value       = var.enabled ? "${var.mount_path}/sign/${var.role_name}" : null
}

output "issue_path" {
  description = "Vault path for issuing certificates"
  value       = var.enabled ? "${var.mount_path}/issue/${var.role_name}" : null
}

# ============================================================================
# Kubernetes Auth Information
# ============================================================================

output "kubernetes_auth_path" {
  description = "Path of the Kubernetes auth backend"
  value       = var.enabled && var.kubernetes_auth.enabled ? vault_auth_backend.kubernetes[0].path : null
}

output "kubernetes_auth_role_name" {
  description = "Name of the Kubernetes auth role for cert-manager"
  value       = var.enabled && var.kubernetes_auth.enabled ? vault_kubernetes_auth_backend_role.cert_manager[0].role_name : null
}

# ============================================================================
# Policy Information
# ============================================================================

output "policy_name" {
  description = "Name of the Vault policy for cert-manager PKI access"
  value       = var.enabled ? vault_policy.cert_manager[0].name : null
}
