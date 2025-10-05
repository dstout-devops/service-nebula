# cert-manager Issuer/ClusterIssuer Submodule Variables

variable "name" {
  description = "Name of the Issuer or ClusterIssuer"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace (required for Issuer, ignored for ClusterIssuer)"
  type        = string
  default     = ""
}

variable "is_cluster_issuer" {
  description = "Whether to create a ClusterIssuer (true) or Issuer (false)"
  type        = bool
  default     = false
}

variable "issuer_spec" {
  description = "The spec block for the Issuer/ClusterIssuer (type-specific: vault, ca, selfSigned, acme, etc.)"
  type        = any
}

variable "labels" {
  description = "Additional labels to apply to resources"
  type        = map(string)
  default     = {}
}

# ServiceAccount configuration (optional, for Vault issuer with Kubernetes auth)
variable "create_service_account" {
  description = "Whether to create a ServiceAccount for the issuer"
  type        = bool
  default     = false
}

variable "service_account_name" {
  description = "Name of the ServiceAccount to create (if create_service_account is true)"
  type        = string
  default     = ""
}

# RBAC configuration (optional, for Vault issuer with Kubernetes auth)
variable "create_token_request_role" {
  description = "Whether to create Role and RoleBinding for token requests"
  type        = bool
  default     = false
}

variable "cert_manager_service_account" {
  description = "Name of the cert-manager ServiceAccount (for token request binding)"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  type        = string
  default     = "cert-manager"
}
