# Vault Issuer Configuration for cert-manager
# This creates the necessary Kubernetes resources for cert-manager to use Vault's PKI engine
# 
# Architecture:
#   1. ServiceAccount: Used by cert-manager to authenticate to Vault
#   2. RBAC: Allows cert-manager controller to create tokens for the ServiceAccount
#   3. Issuer: Configures Vault PKI as a certificate source for cert-manager
#
# Prerequisites:
#   - Vault must be deployed with TLS enabled
#   - Vault PKI secrets engine must be mounted and configured
#   - Vault Kubernetes auth must be enabled and configured
#   - Vault role must be created for cert-manager with appropriate policy

# ============================================================================
# ServiceAccount for Vault Authentication
# ============================================================================

# Create a dedicated ServiceAccount that cert-manager will use to authenticate to Vault
resource "kubernetes_service_account" "vault_issuer" {
  count = var.vault_issuer.enabled ? 1 : 0

  metadata {
    name      = var.vault_issuer.auth.sa_name
    namespace = var.vault_issuer.auth.sa_namespace

    labels = {
      "app.kubernetes.io/name"       = "vault-issuer"
      "app.kubernetes.io/component"  = "auth"
      "app.kubernetes.io/part-of"    = "cert-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  automount_service_account_token = true
}

# ============================================================================
# RBAC for cert-manager to use the ServiceAccount
# ============================================================================

# Create a Role that allows creating tokens for the vault-issuer ServiceAccount
resource "kubernetes_role" "vault_issuer" {
  count = var.vault_issuer.enabled ? 1 : 0

  metadata {
    name      = "${var.vault_issuer.auth.sa_name}-tokenrequest"
    namespace = var.vault_issuer.auth.sa_namespace

    labels = {
      "app.kubernetes.io/name"       = "vault-issuer"
      "app.kubernetes.io/component"  = "rbac"
      "app.kubernetes.io/part-of"    = "cert-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["serviceaccounts/token"]
    resource_names = [var.vault_issuer.auth.sa_name]
    verbs          = ["create"]
  }
}

# Bind the Role to cert-manager's ServiceAccount
# This allows cert-manager controller to create tokens for our vault-issuer SA
resource "kubernetes_role_binding" "vault_issuer" {
  count = var.vault_issuer.enabled ? 1 : 0

  metadata {
    name      = "${var.vault_issuer.auth.sa_name}-tokenrequest"
    namespace = var.vault_issuer.auth.sa_namespace

    labels = {
      "app.kubernetes.io/name"       = "vault-issuer"
      "app.kubernetes.io/component"  = "rbac"
      "app.kubernetes.io/part-of"    = "cert-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_issuer[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    namespace = var.namespace
  }
}

# ============================================================================
# Vault Issuer
# ============================================================================

# Create the Vault Issuer that connects cert-manager to Vault's PKI engine
resource "kubectl_manifest" "vault_issuer" {
  count = var.vault_issuer.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = var.vault_issuer.name
      namespace = var.vault_issuer.auth.sa_namespace
      labels = {
        "app.kubernetes.io/name"       = "vault-issuer"
        "app.kubernetes.io/component"  = "issuer"
        "app.kubernetes.io/part-of"    = "cert-manager"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      vault = merge(
        {
          server = var.vault_issuer.vault_server
          path   = var.vault_issuer.pki_path
          auth = {
            kubernetes = {
              role      = var.vault_issuer.auth.role
              mountPath = var.vault_issuer.auth.mount_path
              serviceAccountRef = merge(
                {
                  name = var.vault_issuer.auth.sa_name
                },
                # Add audiences if provided
                length(var.vault_issuer.auth.audiences) > 0 ? {
                  audiences = var.vault_issuer.auth.audiences
                } : {}
              )
            }
          }
        },
        # Only include caBundle if provided (for TLS)
        var.vault_issuer.vault_ca_bundle != "" ? {
          caBundle = var.vault_issuer.vault_ca_bundle
        } : {}
      )
    }
  })

  depends_on = [
    kubernetes_service_account.vault_issuer,
    kubernetes_role_binding.vault_issuer
  ]
}
