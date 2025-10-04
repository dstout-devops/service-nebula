# Kubernetes Authentication Backend Configuration
# Allows cert-manager to authenticate with Vault and access PKI secrets

# ============================================================================
# Kubernetes Auth Backend
# ============================================================================

resource "vault_auth_backend" "kubernetes" {
  count = var.enabled && var.kubernetes_auth.enabled ? 1 : 0

  type = "kubernetes"
  path = var.kubernetes_auth.path

  description = "Kubernetes authentication backend for cert-manager"
}

# ============================================================================
# Kubernetes Auth Backend Configuration
# ============================================================================

resource "vault_kubernetes_auth_backend_config" "config" {
  count = var.enabled && var.kubernetes_auth.enabled ? 1 : 0

  backend            = vault_auth_backend.kubernetes[0].path
  kubernetes_host    = var.kubernetes_auth.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_auth.kubernetes_ca_cert

  # Use default service account token for auth
  disable_local_ca_jwt = false
}

# ============================================================================
# Kubernetes Auth Backend Role
# ============================================================================

resource "vault_kubernetes_auth_backend_role" "cert_manager" {
  count = var.enabled && var.kubernetes_auth.enabled ? 1 : 0

  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = var.kubernetes_auth.role_name
  bound_service_account_names      = var.kubernetes_auth.service_account_names
  bound_service_account_namespaces = var.kubernetes_auth.service_account_namespaces
  token_ttl                        = var.kubernetes_auth.token_ttl
  token_policies                   = [vault_policy.cert_manager[0].name]

  # Allow token renewal
  token_period = var.kubernetes_auth.token_ttl
}
