# Input Variables for Init Submodule

variable "namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
}

variable "deployment_mode" {
  description = "Vault deployment mode (standalone, standalone-tls, ha-raft, ha-raft-tls)"
  type        = string
}

variable "is_ha" {
  description = "Whether Vault is running in HA mode"
  type        = bool
}

variable "is_tls_enabled" {
  description = "Whether TLS is enabled for Vault"
  type        = bool
}

variable "service_name" {
  description = "Name of the main Vault service"
  type        = string
}

variable "internal_service_name" {
  description = "Name of the internal Vault service for HA communication"
  type        = string
}

variable "vault_protocol" {
  description = "Protocol for Vault communication (http or https)"
  type        = string
}

variable "userconfig_path" {
  description = "Path to TLS certificates in Vault pods"
  type        = string
}

variable "unseal_keys_secret_name" {
  description = "Name of Kubernetes secret to store Vault unseal keys"
  type        = string
}
