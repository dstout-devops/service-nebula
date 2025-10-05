# cert-manager Module Variables
# Following cert-manager documentation:
# https://cert-manager.io/docs/installation/helm/
# https://artifacthub.io/packages/helm/cert-manager/cert-manager

# Basic Configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.18.2"
}

variable "install_crds" {
  description = "Install CRDs as part of the Helm release"
  type        = bool
  default     = true
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

# Component Configuration (Object-Oriented)
variable "controller" {
  description = "cert-manager controller configuration"
  type = object({
    replicas = number
    resources = object({
      requests = object({
        memory = string
        cpu    = string
      })
      limits = object({
        memory = string
        cpu    = string
      })
    })
  })
  default = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "256Mi"
        cpu    = "500m"
      }
    }
  }
}

variable "webhook" {
  description = "cert-manager webhook configuration"
  type = object({
    replicas        = number
    timeout_seconds = number
    resources = object({
      requests = object({
        memory = string
        cpu    = string
      })
      limits = object({
        memory = string
        cpu    = string
      })
    })
  })
  default = {
    replicas        = 1
    timeout_seconds = 10
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "64Mi"
        cpu    = "100m"
      }
    }
  }
}

variable "cainjector" {
  description = "cert-manager CA injector configuration"
  type = object({
    replicas = number
    resources = object({
      requests = object({
        memory = string
        cpu    = string
      })
      limits = object({
        memory = string
        cpu    = string
      })
    })
  })
  default = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "128Mi"
        cpu    = "100m"
      }
    }
  }
}

# Global Configuration
variable "global" {
  description = "Global cert-manager configuration"
  type = object({
    log_level = number
  })
  default = {
    log_level = 2
  }

  validation {
    condition     = var.global.log_level >= 1 && var.global.log_level <= 6
    error_message = "log_level must be between 1 and 6"
  }
}

# Feature Flags
variable "features" {
  description = "Feature flags for cert-manager"
  type = object({
    prometheus      = bool
    startupapicheck = bool
    feature_gates   = string
  })
  default = {
    prometheus      = true
    startupapicheck = true
    feature_gates   = ""
  }
}

# Vault Issuer Configuration (DEPRECATED - use issuer submodule instead)
# Configuration for Vault PKI Issuer - integrates with Vault's PKI secrets engine
# Requires Vault to be deployed first with PKI configured and Kubernetes auth enabled
# 
# NOTE: This variable is deprecated. Use the issuer submodule instead:
#   module "vault_issuer" {
#     source = "./modules/cert-manager/modules/issuer"
#     ...
#   }
variable "vault_issuer" {
  description = "DEPRECATED: Use issuer submodule. Vault PKI Issuer configuration (requires Vault PKI and auth configured)"
  type = object({
    enabled         = bool
    name            = optional(string, "vault-issuer")
    vault_server    = optional(string, "http://vault.vault.svc.cluster.local:8200")
    vault_ca_bundle = optional(string, "")
    pki_path        = optional(string, "pki/sign/cert-manager")
    auth = optional(object({
      role         = string
      mount_path   = string
      sa_name      = string
      sa_namespace = string
      audiences    = list(string)
    }), {
      role         = "cert-manager"
      mount_path   = "/v1/auth/kubernetes"
      sa_name      = "cert-manager"
      sa_namespace = "cert-manager"
      audiences    = []
    })
  })
  default = {
    enabled = false
  }
}

# Vault Injector TLS Certificate Configuration (DEPRECATED - use certificate submodule instead)
# Configuration for Vault Agent Injector webhook TLS certificate (issued by Vault Issuer)
# 
# NOTE: This variable is deprecated. Use the certificate submodule instead:
#   module "vault_injector_cert" {
#     source = "./modules/cert-manager/modules/certificate"
#     ...
#   }
variable "vault_injector_tls" {
  description = <<-EOT
    DEPRECATED: Use certificate submodule. Vault Agent Injector TLS certificate configuration.
    Certificate is issued by Vault PKI (via the Vault Issuer).
    This follows the HashiCorp vendor documentation pattern.
    See: https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
  EOT
  type = object({
    enabled      = bool
    namespace    = optional(string, "vault")
    service_name = optional(string, "vault-agent-injector-svc")
    secret_name  = optional(string, "injector-tls")
    issuer_name  = optional(string, "vault-issuer")
    duration     = optional(string, "2160h")
    renew_before = optional(string, "360h")
    dns_names    = optional(list(string), [])
  })
  default = {
    enabled = false
  }
}
