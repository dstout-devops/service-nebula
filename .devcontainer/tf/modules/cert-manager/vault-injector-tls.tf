# Vault Agent Injector TLS Certificate
# Following HashiCorp vendor documentation:
# https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
# https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/examples/injector-tls-cert-manager
#
# This uses Vault PKI as the issuer for the injector webhook TLS certificate
# NOTE: Requires vault_issuer to be created first (see vault-issuer.tf)

# ============================================================================
# Vault Agent Injector Certificate (issued by Vault PKI)
# ============================================================================

resource "kubectl_manifest" "injector_certificate" {
  count = var.vault_injector_tls.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "injector-certificate"
      namespace = var.vault_injector_tls.namespace
      labels = {
        "app.kubernetes.io/name"       = "vault-agent-injector"
        "app.kubernetes.io/component"  = "webhook-tls"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      secretName  = var.vault_injector_tls.secret_name
      duration    = var.vault_injector_tls.duration
      renewBefore = var.vault_injector_tls.renew_before
      commonName  = "${var.vault_injector_tls.service_name}.${var.vault_injector_tls.namespace}.svc.cluster.local"

      # DNS names for the webhook service (all possible forms)
      dnsNames = length(var.vault_injector_tls.dns_names) > 0 ? var.vault_injector_tls.dns_names : [
        var.vault_injector_tls.service_name,
        "${var.vault_injector_tls.service_name}.${var.vault_injector_tls.namespace}",
        "${var.vault_injector_tls.service_name}.${var.vault_injector_tls.namespace}.svc",
        "${var.vault_injector_tls.service_name}.${var.vault_injector_tls.namespace}.svc.cluster.local"
      ]

      # Reference the Vault issuer (NOT self-signed CA)
      issuerRef = {
        name  = var.vault_injector_tls.issuer_name
        kind  = "Issuer"
        group = "cert-manager.io"
      }
    }
  })
}
