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

# TLS Configuration (simplified - detailed config in tls_config)
variable "tls" {
  description = "Basic TLS enablement and secret name"
  type = object({
    enabled     = bool
    secret_name = string
  })
  default = {
    enabled     = false
    secret_name = "vault-server-tls"
  }
}

# Detailed TLS/CA Configuration (object-oriented structure)
variable "tls_config" {
  description = "Detailed TLS certificate configuration for Vault server"
  type = object({
    root_ca = object({
      common_name         = string
      organization        = string
      organizational_unit = optional(string)
      country             = optional(string)
      locality            = optional(string)
      province            = optional(string)
      key_bits            = optional(number)
      validity_hours      = optional(number)
      early_renewal_hours = optional(number)
    })
    intermediate_ca = object({
      common_name         = string
      organization        = string
      organizational_unit = optional(string)
      country             = optional(string)
      locality            = optional(string)
      province            = optional(string)
      key_bits            = optional(number)
      validity_hours      = optional(number)
      early_renewal_hours = optional(number)
    })
    server_cert = object({
      organization        = string
      organizational_unit = optional(string)
      key_bits            = optional(number)
      validity_hours      = optional(number)
      early_renewal_hours = optional(number)
    })
  })
  default = {
    root_ca = {
      common_name         = "Service Nebula Root CA"
      organization        = "Service Nebula"
      organizational_unit = "Infrastructure"
      country             = "US"
      key_bits            = 4096
      validity_hours      = 87600 # 10 years
      early_renewal_hours = 720   # Renew 30 days before expiry
    }
    intermediate_ca = {
      common_name         = "Service Nebula Intermediate CA"
      organization        = "Service Nebula"
      organizational_unit = "Infrastructure"
      country             = "US"
      key_bits            = 4096
      validity_hours      = 43800 # 5 years
      early_renewal_hours = 720   # Renew 30 days before expiry
    }
    server_cert = {
      organization        = "Service Nebula"
      organizational_unit = "Infrastructure"
      key_bits            = 2048
      validity_hours      = 2160 # 90 days
      early_renewal_hours = 168  # Renew 7 days before expiry
    }
  }
}

# Storage Configuration
variable "storage" {
  description = "Storage configuration for Vault data persistence"
  type = object({
    size  = string
    class = string
  })
  default = {
    size  = "10Gi"
    class = "standard"
  }
}

# UI Configuration
variable "enable_ui" {
  description = "Enable Vault UI"
  type        = bool
  default     = true
}

# Service Configuration
variable "service_type" {
  description = "Kubernetes service type for main Vault service"
  type        = string
  default     = "ClusterIP"
}

variable "service_name" {
  description = "Name of the main Vault service"
  type        = string
  default     = "vault"
}

variable "internal_service_name" {
  description = "Name of the internal Vault service for HA communication"
  type        = string
  default     = "vault-internal"
}

variable "ui_service_name" {
  description = "Name of the Vault UI service"
  type        = string
  default     = "vault-ui"
}

variable "active_service_name" {
  description = "Name of the Vault active service"
  type        = string
  default     = "vault-active"
}

variable "standby_service_name" {
  description = "Name of the Vault standby service"
  type        = string
  default     = "vault-standby"
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

# Network Configuration
variable "listener" {
  description = "Vault listener configuration"
  type = object({
    api_addr     = string
    cluster_addr = string
  })
  default = {
    api_addr     = "[::]:8200"
    cluster_addr = "[::]:8201"
  }
}

# Path Configuration
variable "paths" {
  description = "Vault path configuration"
  type = object({
    data_path       = string
    userconfig_path = string
  })
  default = {
    data_path       = "/vault/data"
    userconfig_path = "/vault/userconfig/vault-server-tls"
  }
}

# Unseal Keys Configuration
variable "unseal_keys_secret_name" {
  description = "Name of the Kubernetes secret to store unseal keys"
  type        = string
  default     = "vault-unseal-keys"
}

# Vault Agent Injector Configuration
variable "injector" {
  description = "Vault Agent Injector configuration"
  type = object({
    enabled             = bool
    replicas            = number
    leader_elector      = bool
    use_cert_manager    = bool
    tls_secret_name     = string
    webhook_annotations = map(string)
  })
  default = {
    enabled             = true
    replicas            = 1
    leader_elector      = true
    use_cert_manager    = false
    tls_secret_name     = "injector-tls"
    webhook_annotations = {}
  }
}

# PKI Secrets Engine Configuration (object-oriented structure)
variable "pki_engine" {
  description = "PKI secrets engine configuration for cert-manager integration"
  type = object({
    enabled         = bool
    mount_path      = string
    max_ttl_seconds = number

    root_ca = object({
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

    role_name                   = string
    allowed_domains             = list(string)
    allow_subdomains            = bool
    allow_bare_domains          = bool
    allow_glob_domains          = bool
    allow_any_name              = bool
    allow_localhost             = bool
    allow_ip_sans               = bool
    allow_wildcard_certificates = bool
    cert_max_ttl_seconds        = number
    cert_default_ttl_seconds    = number
    cert_key_type               = string
    cert_key_bits               = number

    kubernetes_auth = object({
      enabled                    = bool
      path                       = string
      kubernetes_host            = string
      role_name                  = string
      service_account_names      = list(string)
      service_account_namespaces = list(string)
      token_ttl                  = number
    })

    policy_name = string
  })
  default = {
    enabled         = false
    mount_path      = "pki"
    max_ttl_seconds = 315360000 # 10 years

    root_ca = {
      common_name         = "Vault PKI Root CA"
      organization        = "Service Nebula"
      organizational_unit = "Platform Engineering"
      country             = "US"
      locality            = null
      province            = null
      key_type            = "rsa"
      key_bits            = 4096
      max_path_length     = 1
    }

    role_name = "cert-manager"
    allowed_domains = [
      "svc.cluster.local",
      "*.svc.cluster.local",
      "vault.svc.cluster.local",
      "cert-manager.svc.cluster.local"
    ]
    allow_subdomains            = true
    allow_bare_domains          = true
    allow_glob_domains          = true
    allow_any_name              = false # Restrict to allowed_domains
    allow_localhost             = true
    allow_ip_sans               = true
    allow_wildcard_certificates = false
    cert_max_ttl_seconds        = 7776000 # 90 days
    cert_default_ttl_seconds    = 7776000 # 90 days
    cert_key_type               = "rsa"
    cert_key_bits               = 2048

    kubernetes_auth = {
      enabled                    = true
      path                       = "kubernetes"
      kubernetes_host            = "https://kubernetes.default.svc"
      role_name                  = "cert-manager"
      service_account_names      = ["cert-manager"]
      service_account_namespaces = ["cert-manager"]
      token_ttl                  = 3600 # 1 hour
    }

    policy_name = "cert-manager-pki"
  }
}
