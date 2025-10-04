# Vault TLS/CA Infrastructure Submodule
# Manages the CA hierarchy and TLS certificates for Vault server deployment
# This is for Vault's own TLS communications, NOT for the PKI secrets engine

terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# ============================================================================
# Root CA
# ============================================================================

resource "tls_private_key" "root_ca" {
  count = var.enabled ? 1 : 0

  algorithm   = var.root_ca.key_algorithm
  rsa_bits    = var.root_ca.key_bits
  ecdsa_curve = var.root_ca.ecdsa_curve
}

resource "tls_self_signed_cert" "root_ca" {
  count = var.enabled ? 1 : 0

  private_key_pem = tls_private_key.root_ca[0].private_key_pem

  subject {
    common_name  = var.root_ca.common_name
    organization = var.root_ca.organization
  }

  validity_period_hours = var.root_ca.validity_hours
  early_renewal_hours   = var.root_ca.early_renewal_hours

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]

  is_ca_certificate = true
}

# ============================================================================
# Intermediate CA
# ============================================================================

resource "tls_private_key" "intermediate_ca" {
  count = var.enabled ? 1 : 0

  algorithm   = var.intermediate_ca.key_algorithm
  rsa_bits    = var.intermediate_ca.key_bits
  ecdsa_curve = var.intermediate_ca.ecdsa_curve
}

resource "tls_cert_request" "intermediate_ca" {
  count = var.enabled ? 1 : 0

  private_key_pem = tls_private_key.intermediate_ca[0].private_key_pem

  subject {
    common_name  = var.intermediate_ca.common_name
    organization = var.intermediate_ca.organization
  }
}

resource "tls_locally_signed_cert" "intermediate_ca" {
  count = var.enabled ? 1 : 0

  cert_request_pem   = tls_cert_request.intermediate_ca[0].cert_request_pem
  ca_private_key_pem = tls_private_key.root_ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca[0].cert_pem

  validity_period_hours = var.intermediate_ca.validity_hours
  early_renewal_hours   = var.intermediate_ca.early_renewal_hours

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]

  is_ca_certificate = true
}

# ============================================================================
# Vault Server Certificate
# ============================================================================

resource "tls_private_key" "vault_server" {
  count = var.enabled ? 1 : 0

  algorithm   = var.server_cert.key_algorithm
  rsa_bits    = var.server_cert.key_bits
  ecdsa_curve = var.server_cert.ecdsa_curve
}

resource "tls_cert_request" "vault_server" {
  count = var.enabled ? 1 : 0

  private_key_pem = tls_private_key.vault_server[0].private_key_pem

  subject {
    common_name  = var.server_cert.common_name
    organization = var.server_cert.organization
  }

  dns_names    = var.server_cert.dns_names
  ip_addresses = var.server_cert.ip_addresses
}

resource "tls_locally_signed_cert" "vault_server" {
  count = var.enabled ? 1 : 0

  cert_request_pem   = tls_cert_request.vault_server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.intermediate_ca[0].private_key_pem
  ca_cert_pem        = tls_locally_signed_cert.intermediate_ca[0].cert_pem

  validity_period_hours = var.server_cert.validity_hours
  early_renewal_hours   = var.server_cert.early_renewal_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# ============================================================================
# Kubernetes Secret for Vault TLS
# ============================================================================

resource "kubernetes_secret" "vault_tls" {
  count = var.enabled && var.create_k8s_secret ? 1 : 0

  metadata {
    name      = var.k8s_secret_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "vault"
      "app.kubernetes.io/component"  = "tls"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    "vault.key" = tls_private_key.vault_server[0].private_key_pem
    "vault.crt" = tls_locally_signed_cert.vault_server[0].cert_pem
    # Full chain: intermediate + root (for client verification)
    "vault.ca" = "${tls_locally_signed_cert.intermediate_ca[0].cert_pem}${tls_self_signed_cert.root_ca[0].cert_pem}"
  }
}
