# =============================================================================
# Traefik TLS Submodule
# =============================================================================
# This module manages Traefik TLS configurations including TLS stores,
# certificate resolvers, and TLS options.

# TLS Store
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "tls_store" {
  for_each = var.tls_stores

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TLSStore"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      defaultCertificate = try(each.value.default_certificate, null)
      certificates       = try(each.value.certificates, [])
    }
  })
}

# TLS Options
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "tls_option" {
  for_each = var.tls_options

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TLSOption"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      minVersion               = try(each.value.min_version, "VersionTLS12")
      maxVersion               = try(each.value.max_version, null)
      cipherSuites            = try(each.value.cipher_suites, [])
      curvePreferences        = try(each.value.curve_preferences, [])
      clientAuth              = try(each.value.client_auth, null)
      sniStrict               = try(each.value.sni_strict, false)
      alpnProtocols           = try(each.value.alpn_protocols, [])
    }
  })
}

# Kubernetes Secret for Certificates
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "certificate_secret" {
  for_each = var.certificate_secrets

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    type       = "kubernetes.io/tls"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
      annotations = try(each.value.annotations, {})
    }
    data = {
      "tls.crt" = each.value.cert
      "tls.key" = each.value.key
    }
  })
}

# cert-manager Certificate Resources (if using cert-manager)
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "certificate" {
  for_each = var.certificates

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      secretName = each.value.secret_name
      issuerRef = {
        name  = each.value.issuer_ref.name
        kind  = try(each.value.issuer_ref.kind, "ClusterIssuer")
        group = try(each.value.issuer_ref.group, "cert-manager.io")
      }
      commonName = try(each.value.common_name, null)
      dnsNames   = try(each.value.dns_names, [])
      ipAddresses = try(each.value.ip_addresses, [])
      duration    = try(each.value.duration, "2160h")
      renewBefore = try(each.value.renew_before, "360h")
      privateKey = {
        algorithm      = try(each.value.private_key.algorithm, "RSA")
        encoding       = try(each.value.private_key.encoding, "PKCS1")
        size           = try(each.value.private_key.size, 2048)
        rotationPolicy = try(each.value.private_key.rotation_policy, "Never")
      }
      usages = try(each.value.usages, [
        "digital signature",
        "key encipherment"
      ])
    }
  })
}

# ServersTransport for TLS config on backend connections
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "servers_transport" {
  for_each = var.servers_transports

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "ServersTransport"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      serverName          = try(each.value.server_name, null)
      insecureSkipVerify = try(each.value.insecure_skip_verify, false)
      rootCAsSecrets     = try(each.value.root_cas_secrets, [])
      certificatesSecrets = try(each.value.certificates_secrets, [])
      maxIdleConnsPerHost = try(each.value.max_idle_conns_per_host, null)
      forwardingTimeouts = try(each.value.forwarding_timeouts, null)
      peerCertURI        = try(each.value.peer_cert_uri, null)
    }
  })
}
