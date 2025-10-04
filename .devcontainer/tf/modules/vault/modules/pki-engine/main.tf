# Vault PKI Secrets Engine Submodule
# Manages PKI secrets engine configuration for cert-manager integration
# This is for issuing APPLICATION certificates, NOT for Vault server TLS

terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
    }
  }
}

# ============================================================================
# PKI Secrets Engine Mount
# ============================================================================

resource "vault_mount" "pki" {
  count = var.enabled ? 1 : 0

  path        = var.mount_path
  type        = "pki"
  description = "PKI secrets engine for cert-manager certificate issuance"

  # Maximum TTL for certificates issued by this mount
  # Certs can have shorter TTLs but not longer than this
  max_lease_ttl_seconds = var.max_ttl_seconds
}

# ============================================================================
# PKI URLs Configuration
# ============================================================================

resource "vault_pki_secret_backend_config_urls" "pki" {
  count = var.enabled ? 1 : 0

  backend = vault_mount.pki[0].path

  issuing_certificates = [
    "${var.vault_addr}/v1/${var.mount_path}/ca"
  ]
  crl_distribution_points = [
    "${var.vault_addr}/v1/${var.mount_path}/crl"
  ]
}

# ============================================================================
# PKI Root CA
# ============================================================================

# Generate a root CA directly in Vault PKI
# This is simpler and more secure than importing external CA
# The private key never leaves Vault
resource "vault_pki_secret_backend_root_cert" "pki" {
  count = var.enabled ? 1 : 0

  backend     = vault_mount.pki[0].path
  type        = "internal" # Generate key within Vault (keeps it secure)
  common_name = var.root_ca.common_name
  ttl         = var.max_ttl_seconds

  # Certificate properties
  organization = var.root_ca.organization
  ou           = var.root_ca.organizational_unit
  country      = var.root_ca.country
  locality     = var.root_ca.locality
  province     = var.root_ca.province

  # Key configuration
  key_type = var.root_ca.key_type
  key_bits = var.root_ca.key_bits

  # CA constraints
  exclude_cn_from_sans = true
  max_path_length      = var.root_ca.max_path_length
}

# ============================================================================
# PKI Default Issuer Configuration
# ============================================================================

# Vault 1.11+ requires explicit default issuer configuration
resource "vault_pki_secret_backend_config_issuers" "config" {
  count = var.enabled ? 1 : 0

  backend = vault_mount.pki[0].path
  default = vault_pki_secret_backend_root_cert.pki[0].issuer_id
}

# ============================================================================
# PKI Role for cert-manager
# ============================================================================

resource "vault_pki_secret_backend_role" "cert_manager" {
  count = var.enabled ? 1 : 0

  backend = vault_mount.pki[0].path
  name    = var.role_name

  # Domain allowlist
  allowed_domains    = var.allowed_domains
  allow_subdomains   = var.allow_subdomains
  allow_bare_domains = var.allow_bare_domains
  allow_glob_domains = var.allow_glob_domains
  allow_any_name     = var.allow_any_name

  # Additional flexibility for internal services
  allow_localhost             = var.allow_localhost
  allow_ip_sans               = var.allow_ip_sans
  allow_wildcard_certificates = var.allow_wildcard_certificates

  # Certificate settings
  max_ttl    = var.cert_max_ttl_seconds
  ttl        = var.cert_default_ttl_seconds
  no_store   = false
  require_cn = true

  # Key configuration
  key_type = var.cert_key_type
  key_bits = var.cert_key_bits

  # Certificate usage
  server_flag = true
  client_flag = true

  # Standard key usages for TLS
  key_usage = [
    "DigitalSignature",
    "KeyAgreement",
    "KeyEncipherment"
  ]
}
