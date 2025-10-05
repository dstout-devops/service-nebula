# =============================================================================
# TLS Submodule Variables
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace for TLS resources"
  type        = string
}

# TLS Stores
# -----------------------------------------------------------------------------
variable "tls_stores" {
  description = "Map of TLS store configurations"
  type = map(object({
    labels             = optional(map(string))
    default_certificate = optional(object({
      secretName = string
    }))
    certificates = optional(list(object({
      secretName = string
    })))
  }))
  default = {}
}

# TLS Options
# -----------------------------------------------------------------------------
variable "tls_options" {
  description = "Map of TLS option configurations"
  type = map(object({
    labels             = optional(map(string))
    min_version        = optional(string)
    max_version        = optional(string)
    cipher_suites      = optional(list(string))
    curve_preferences  = optional(list(string))
    sni_strict         = optional(bool)
    alpn_protocols     = optional(list(string))
    client_auth        = optional(object({
      secretNames        = list(string)
      clientAuthType     = optional(string)
    }))
  }))
  default = {}
}

# Certificate Secrets (raw TLS secrets)
# -----------------------------------------------------------------------------
variable "certificate_secrets" {
  description = "Map of Kubernetes TLS secrets to create"
  type = map(object({
    labels      = optional(map(string))
    annotations = optional(map(string))
    cert        = string # Base64-encoded certificate
    key         = string # Base64-encoded private key
  }))
  default = {}
}

# cert-manager Certificates
# -----------------------------------------------------------------------------
variable "certificates" {
  description = "Map of cert-manager Certificate configurations"
  type = map(object({
    labels       = optional(map(string))
    secret_name  = string
    issuer_ref = object({
      name  = string
      kind  = optional(string)
      group = optional(string)
    })
    common_name   = optional(string)
    dns_names     = optional(list(string))
    ip_addresses  = optional(list(string))
    duration      = optional(string)
    renew_before  = optional(string)
    private_key = optional(object({
      algorithm        = optional(string)
      encoding         = optional(string)
      size             = optional(number)
      rotation_policy  = optional(string)
    }))
    usages = optional(list(string))
  }))
  default = {}
}

# ServersTransport
# -----------------------------------------------------------------------------
variable "servers_transports" {
  description = "Map of ServersTransport configurations for backend TLS"
  type = map(object({
    labels                  = optional(map(string))
    server_name             = optional(string)
    insecure_skip_verify    = optional(bool)
    root_cas_secrets        = optional(list(string))
    certificates_secrets    = optional(list(string))
    max_idle_conns_per_host = optional(number)
    peer_cert_uri           = optional(string)
    forwarding_timeouts = optional(object({
      dialTimeout          = optional(string)
      responseHeaderTimeout = optional(string)
      idleConnTimeout      = optional(string)
    }))
  }))
  default = {}
}
