# TLS Submodule Variables
# Configuration for Vault server TLS/CA infrastructure

variable "enabled" {
  description = "Enable TLS configuration for Vault server"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  type        = string
}

variable "create_k8s_secret" {
  description = "Create Kubernetes secret with TLS certificates"
  type        = bool
  default     = true
}

variable "k8s_secret_name" {
  description = "Name of the Kubernetes secret to store TLS certificates"
  type        = string
  default     = "vault-server-tls"
}

# Root CA Configuration
variable "root_ca" {
  description = "Root CA certificate configuration"
  type = object({
    common_name         = string
    organization        = string
    organizational_unit = optional(string)
    country             = optional(string)
    locality            = optional(string)
    province            = optional(string)
    key_algorithm       = string
    key_bits            = number
    ecdsa_curve         = optional(string)
    validity_hours      = number
    early_renewal_hours = number
  })
  default = {
    common_name         = "Service Nebula Root CA"
    organization        = "Service Nebula"
    organizational_unit = "Infrastructure"
    country             = "US"
    key_algorithm       = "RSA"
    key_bits            = 4096
    ecdsa_curve         = "P384"
    validity_hours      = 87600 # 10 years
    early_renewal_hours = 8760  # 1 year
  }
}

# Intermediate CA Configuration
variable "intermediate_ca" {
  description = "Intermediate CA certificate configuration"
  type = object({
    common_name         = string
    organization        = string
    organizational_unit = optional(string)
    country             = optional(string)
    locality            = optional(string)
    province            = optional(string)
    key_algorithm       = string
    key_bits            = number
    ecdsa_curve         = optional(string)
    validity_hours      = number
    early_renewal_hours = number
  })
  default = {
    common_name         = "Service Nebula Vault Intermediate CA"
    organization        = "Service Nebula"
    organizational_unit = "Infrastructure"
    country             = "US"
    key_algorithm       = "RSA"
    key_bits            = 4096
    ecdsa_curve         = "P384"
    validity_hours      = 43800 # 5 years
    early_renewal_hours = 4380  # 6 months
  }
}

# Server Certificate Configuration
variable "server_cert" {
  description = "Vault server certificate configuration"
  type = object({
    common_name         = string
    organization        = string
    organizational_unit = optional(string)
    dns_names           = list(string)
    ip_addresses        = list(string)
    key_algorithm       = string
    key_bits            = number
    ecdsa_curve         = optional(string)
    validity_hours      = number
    early_renewal_hours = number
  })
  default = {
    common_name         = "vault.vault.svc.cluster.local"
    organization        = "Service Nebula"
    organizational_unit = "Infrastructure"
    dns_names           = []
    ip_addresses        = []
    key_algorithm       = "RSA"
    key_bits            = 2048
    ecdsa_curve         = "P256"
    validity_hours      = 2160 # 90 days
    early_renewal_hours = 720  # 30 days
  }
}
