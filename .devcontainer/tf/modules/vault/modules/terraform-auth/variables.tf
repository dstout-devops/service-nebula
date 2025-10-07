variable "enabled" {
  description = "Enable Terraform authentication configuration"
  type        = bool
  default     = true
}

variable "create_auth_backend" {
  description = "Create the Kubernetes auth backend (set to false if it already exists)"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for Terraform service account"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for Terraform"
  type        = string
  default     = "terraform"
}

variable "role_name" {
  description = "Name of the Vault Kubernetes auth role for Terraform"
  type        = string
  default     = "terraform"
}

variable "policy_name" {
  description = "Name of the Vault policy for Terraform"
  type        = string
  default     = "terraform"
}

variable "kubernetes_auth_path" {
  description = "Path to the Kubernetes auth backend in Vault"
  type        = string
  default     = "kubernetes"
}

variable "kubernetes_host" {
  description = "Kubernetes API host for Vault auth config"
  type        = string
  default     = "https://kubernetes.default.svc:443"
}

variable "kubernetes_ca_cert" {
  description = "Kubernetes CA certificate for Vault auth config"
  type        = string
  default     = ""
}

variable "token_ttl" {
  description = "TTL for Terraform tokens (in seconds)"
  type        = number
  default     = 3600 # 1 hour
}

variable "token_policies" {
  description = "List of policies to attach to the Terraform role"
  type        = list(string)
  default     = []
}

variable "pki_mount_path" {
  description = "Mount path for the PKI secrets engine"
  type        = string
  default     = "pki"
}
