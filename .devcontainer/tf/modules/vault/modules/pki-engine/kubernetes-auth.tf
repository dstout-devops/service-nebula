# Kubernetes Authentication Backend Configuration
# Allows cert-manager to authenticate with Vault and access PKI secrets
# Note: The auth backend itself is created by the terraform-auth module in Stage 2

# ============================================================================
# Kubernetes Auth Backend Role for cert-manager
# ============================================================================

resource "vault_kubernetes_auth_backend_role" "cert_manager" {
  count = var.enabled && var.kubernetes_auth.enabled ? 1 : 0

  backend                          = var.kubernetes_auth.path
  role_name                        = var.kubernetes_auth.role_name
  bound_service_account_names      = var.kubernetes_auth.service_account_names
  bound_service_account_namespaces = var.kubernetes_auth.service_account_namespaces
  token_ttl                        = var.kubernetes_auth.token_ttl
  token_policies                   = [vault_policy.cert_manager[0].name]

  # Allow token renewal
  token_period = var.kubernetes_auth.token_ttl
}
