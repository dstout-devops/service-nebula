# cert-manager Certificate Submodule Variables

variable "name" {
  description = "Name of the Certificate resource"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the Certificate"
  type        = string
}

variable "secret_name" {
  description = "Name of the Kubernetes secret where certificate will be stored"
  type        = string
}

variable "issuer_name" {
  description = "Name of the Issuer or ClusterIssuer"
  type        = string
}

variable "issuer_kind" {
  description = "Kind of issuer (Issuer or ClusterIssuer)"
  type        = string
  default     = "Issuer"
}

variable "issuer_group" {
  description = "API group of the issuer"
  type        = string
  default     = "cert-manager.io"
}

variable "common_name" {
  description = "Common name (CN) for the certificate"
  type        = string
}

variable "dns_names" {
  description = "List of DNS names (SANs) for the certificate"
  type        = list(string)
  default     = []
}

variable "generate_dns_names" {
  description = "Auto-generate DNS names based on service_name and namespace"
  type        = bool
  default     = false
}

variable "service_name" {
  description = "Service name (used for auto-generating DNS names if generate_dns_names=true)"
  type        = string
  default     = ""
}

variable "ip_addresses" {
  description = "List of IP addresses (SANs) for the certificate"
  type        = list(string)
  default     = []
}

variable "email_addresses" {
  description = "List of email addresses (SANs) for the certificate"
  type        = list(string)
  default     = []
}

variable "uris" {
  description = "List of URIs (SANs) for the certificate"
  type        = list(string)
  default     = []
}

variable "duration" {
  description = "Certificate validity duration (e.g., '2160h' for 90 days)"
  type        = string
  default     = "2160h"
}

variable "renew_before" {
  description = "Renew certificate before this duration (e.g., '360h' for 15 days)"
  type        = string
  default     = "360h"
}

variable "private_key_algorithm" {
  description = "Private key algorithm (RSA, ECDSA, Ed25519)"
  type        = string
  default     = ""
}

variable "private_key_size" {
  description = "Private key size (e.g., 2048, 4096 for RSA; 256, 384 for ECDSA)"
  type        = number
  default     = 2048
}

variable "usages" {
  description = "X.509 key usages"
  type        = list(string)
  default = [
    "digital signature",
    "key encipherment",
    "server auth",
    "client auth"
  ]
}

variable "subject" {
  description = "X.509 subject fields"
  type = object({
    organizations       = optional(list(string))
    countries           = optional(list(string))
    organizationalUnits = optional(list(string))
    localities          = optional(list(string))
    provinces           = optional(list(string))
    streetAddresses     = optional(list(string))
    postalCodes         = optional(list(string))
    serialNumber        = optional(string)
  })
  default = null
}

variable "labels" {
  description = "Additional labels for the Certificate resource"
  type        = map(string)
  default     = {}
}

variable "component" {
  description = "Component label value (e.g., 'webhook-tls', 'api-tls')"
  type        = string
  default     = "certificate"
}

variable "annotations" {
  description = "Annotations for the Certificate resource"
  type        = map(string)
  default     = {}
}
