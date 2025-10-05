# cert-manager Certificate Submodule
# Generic submodule for creating cert-manager Certificate resources
# Can be used with any Issuer or ClusterIssuer
resource "kubectl_manifest" "certificate" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = merge(
        var.labels,
        {
          "app.kubernetes.io/name"       = var.name
          "app.kubernetes.io/component"  = var.component
          "app.kubernetes.io/managed-by" = "terraform"
        }
      )
      annotations = var.annotations
    }
    spec = {
      secretName  = var.secret_name
      duration    = var.duration
      renewBefore = var.renew_before
      commonName  = var.common_name

      # DNS names for the certificate
      dnsNames = length(var.dns_names) > 0 ? var.dns_names : (
        var.generate_dns_names ? [
          var.service_name,
          "${var.service_name}.${var.namespace}",
          "${var.service_name}.${var.namespace}.svc",
          "${var.service_name}.${var.namespace}.svc.cluster.local"
        ] : []
      )

      # IP SANs (if any)
      ipAddresses = var.ip_addresses

      # Issuer reference
      issuerRef = {
        name  = var.issuer_name
        kind  = var.issuer_kind
        group = var.issuer_group
      }

      # Private key configuration
      privateKey = var.private_key_algorithm != "" ? {
        algorithm = var.private_key_algorithm
        size      = var.private_key_size
      } : null

      # Usages
      usages = var.usages

      # Subject (if specified)
      subject = var.subject != null ? var.subject : null

      # Email SANs (if any)
      emailAddresses = var.email_addresses

      # URI SANs (if any)
      uris = var.uris
    }
  })
}
