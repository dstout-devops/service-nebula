# Variables for Vault PKI Secrets Engine Submodule

# ============================================================================
# General Configuration
# ============================================================================

variable "enabled" {
  description = "Enable or disable the PKI secrets engine"
  type        = bool
  default     = true
}

variable "mount_path" {
  description = "Path where the PKI secrets engine will be mounted"
  type        = string
  default     = "pki"
}

variable "vault_addr" {
  description = "Vault server address for PKI URLs configuration"
  type        = string
  default     = "https://vault.vault.svc.cluster.local:8200"
}

variable "max_ttl_seconds" {
  description = "Maximum TTL for all certificates issued by this PKI mount (in seconds)"
  type        = number
  default     = 315360000 # 10 years
}

# ============================================================================
# Root CA Configuration
# ============================================================================

variable "root_ca" {
  description = "Root CA configuration for PKI secrets engine"
  type = object({
    common_name         = string
    organization        = string
    organizational_unit = optional(string)
    country             = optional(string)
    locality            = optional(string)
    province            = optional(string)
    key_type            = optional(string)
    key_bits            = optional(number)
    max_path_length     = optional(number)
  })
  default = {
    common_name         = "Vault PKI Root CA"
    organization        = "HashiCorp"
    organizational_unit = "Platform Engineering"
    country             = "US"
    key_type            = "rsa"
    key_bits            = 4096
    max_path_length     = 1
  }
}

# ============================================================================
# PKI Role Configuration
# ============================================================================

variable "role_name" {
  description = "Name of the PKI role for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "allowed_domains" {
  description = "List of domains allowed for certificate issuance"
  type        = list(string)
  default = [
    "svc.cluster.local",
    "*.svc.cluster.local"
  ] # Restrict to cluster-local services by default
}

variable "allow_subdomains" {
  description = "Allow subdomains of allowed domains"
  type        = bool
  default     = true
}

variable "allow_bare_domains" {
  description = "Allow bare domains (without subdomain)"
  type        = bool
  default     = true
}

variable "allow_glob_domains" {
  description = "Allow glob patterns in allowed domains"
  type        = bool
  default     = true
}

variable "allow_any_name" {
  description = "Allow any common name (should be false for production security)"
  type        = bool
  default     = false
}

variable "allow_localhost" {
  description = "Allow localhost in certificate SANs"
  type        = bool
  default     = true
}

variable "allow_ip_sans" {
  description = "Allow IP addresses in certificate SANs"
  type        = bool
  default     = true
}

variable "allow_wildcard_certificates" {
  description = "Allow wildcard certificates (should be false for production security)"
  type        = bool
  default     = false
}

variable "cert_max_ttl_seconds" {
  description = "Maximum TTL for certificates issued via this role (in seconds)"
  type        = number
  default     = 7776000 # 90 days
}

variable "cert_default_ttl_seconds" {
  description = "Default TTL for certificates issued via this role (in seconds)"
  type        = number
  default     = 7776000 # 90 days
}

variable "cert_key_type" {
  description = "Key type for issued certificates"
  type        = string
  default     = "rsa"

  validation {
    condition     = contains(["rsa", "ec"], var.cert_key_type)
    error_message = "cert_key_type must be either 'rsa' or 'ec'"
  }
}

variable "cert_key_bits" {
  description = "Key size for issued certificates"
  type        = number
  default     = 2048

  validation {
    condition     = contains([2048, 4096, 256, 384, 521], var.cert_key_bits)
    error_message = "cert_key_bits must be 2048 or 4096 for RSA, or 256, 384, or 521 for EC"
  }
}

# ============================================================================
# Kubernetes Authentication Configuration
# ============================================================================

variable "kubernetes_auth" {
  description = "Kubernetes authentication backend configuration"
  type = object({
    enabled                    = bool
    path                       = optional(string)
    kubernetes_host            = string
    kubernetes_ca_cert         = string
    role_name                  = optional(string)
    service_account_names      = list(string)
    service_account_namespaces = list(string)
    token_ttl                  = optional(number)
  })
  default = {
    enabled                    = true
    path                       = "kubernetes"
    kubernetes_host            = "https://kubernetes.default.svc"
    kubernetes_ca_cert         = "" # Will be provided by parent module
    role_name                  = "cert-manager"
    service_account_names      = ["cert-manager"]
    service_account_namespaces = ["cert-manager"]
    token_ttl                  = 3600 # 1 hour
  }
}

# ============================================================================
# Policy Configuration
# ============================================================================

variable "policy_name" {
  description = "Name of the Vault policy for cert-manager PKI access"
  type        = string
  default     = "cert-manager-pki"
}
