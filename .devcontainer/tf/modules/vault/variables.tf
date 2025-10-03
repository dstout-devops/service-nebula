# Vault Module Variables
# Following HashiCorp documentation: 
# https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/examples

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.31.0"
}

# Deployment mode configuration
variable "deployment_mode" {
  description = "Vault deployment mode: standalone, standalone-tls, ha-raft, ha-raft-tls"
  type        = string
  default     = "standalone"
  
  validation {
    condition     = contains(["standalone", "standalone-tls", "ha-raft", "ha-raft-tls"], var.deployment_mode)
    error_message = "deployment_mode must be one of: standalone, standalone-tls, ha-raft, ha-raft-tls"
  }
}

# HA Configuration
variable "ha_replicas" {
  description = "Number of Vault replicas for HA mode"
  type        = number
  default     = 3
}

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Vault"
  type        = bool
  default     = false
}

variable "tls_secret_name" {
  description = "Name of Kubernetes secret containing TLS certificates"
  type        = string
  default     = "vault-server-tls"
}

# Storage Configuration
variable "storage_size" {
  description = "Storage size for Vault data"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for Vault PVC"
  type        = string
  default     = "standard"
}

# UI Configuration
variable "enable_ui" {
  description = "Enable Vault UI"
  type        = bool
  default     = true
}

# Service Configuration
variable "service_type" {
  description = "Kubernetes service type"
  type        = string
  default     = "ClusterIP"
}

# Injector Configuration
variable "enable_injector" {
  description = "Enable Vault Agent Injector"
  type        = bool
  default     = true
}

# Resource Limits
variable "server_resources" {
  description = "Resource requests and limits for Vault server"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "256Mi"
      cpu    = "250m"
    }
    limits = {
      memory = "512Mi"
      cpu    = "500m"
    }
  }
}
