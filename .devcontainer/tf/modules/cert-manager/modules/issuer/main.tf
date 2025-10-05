# cert-manager Issuer/ClusterIssuer Submodule
# Generic submodule for creating cert-manager Issuers or ClusterIssuers
# Supports multiple issuer types: Vault, CA, SelfSigned, ACME, etc.

# Create ServiceAccount for issuer authentication (if needed)
resource "kubernetes_service_account" "issuer" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    labels = merge(
      var.labels,
      {
        "app.kubernetes.io/name"       = var.name
        "app.kubernetes.io/component"  = "auth"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  automount_service_account_token = true
}

# Create Role for token requests (needed for Vault issuer with Kubernetes auth)
resource "kubernetes_role" "token_request" {
  count = var.create_token_request_role ? 1 : 0

  metadata {
    name      = "${var.service_account_name}-tokenrequest"
    namespace = var.namespace

    labels = merge(
      var.labels,
      {
        "app.kubernetes.io/name"       = var.name
        "app.kubernetes.io/component"  = "rbac"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  rule {
    api_groups     = [""]
    resources      = ["serviceaccounts/token"]
    resource_names = [var.service_account_name]
    verbs          = ["create"]
  }
}

# Bind the Role to cert-manager's ServiceAccount
resource "kubernetes_role_binding" "token_request" {
  count = var.create_token_request_role ? 1 : 0

  metadata {
    name      = "${var.service_account_name}-tokenrequest"
    namespace = var.namespace

    labels = merge(
      var.labels,
      {
        "app.kubernetes.io/name"       = var.name
        "app.kubernetes.io/component"  = "rbac"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    )
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.token_request[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.cert_manager_service_account
    namespace = var.cert_manager_namespace
  }
}

# Create the Issuer or ClusterIssuer
resource "kubectl_manifest" "issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = var.is_cluster_issuer ? "ClusterIssuer" : "Issuer"
    metadata = merge(
      {
        name = var.name
      },
      var.is_cluster_issuer ? {} : { namespace = var.namespace },
      {
        labels = merge(
          var.labels,
          {
            "app.kubernetes.io/name"       = var.name
            "app.kubernetes.io/component"  = "issuer"
            "app.kubernetes.io/managed-by" = "terraform"
          }
        )
      }
    )
    spec = var.issuer_spec
  })

  depends_on = [
    kubernetes_service_account.issuer,
    kubernetes_role_binding.token_request
  ]
}
