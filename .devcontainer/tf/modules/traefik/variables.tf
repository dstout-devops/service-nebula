# =============================================================================
# Traefik Module Variables
# =============================================================================

# Namespace Configuration
# -----------------------------------------------------------------------------
variable "namespace" {
  description = "Kubernetes namespace for Traefik"
  type        = string
  default     = "traefik"
}

variable "create_namespace" {
  description = "Whether to create the namespace"
  type        = bool
  default     = true
}

# Helm Chart Configuration
# -----------------------------------------------------------------------------
variable "release_name" {
  description = "Helm release name for Traefik"
  type        = string
  default     = "traefik"
}

variable "chart_version" {
  description = "Version of the Traefik Helm chart"
  type        = string
  default     = "33.2.1" # Latest stable as of Oct 2025
}

variable "helm_values" {
  description = "Additional Helm values to set"
  type        = map(string)
  default     = {}
}

# Global Configuration
# -----------------------------------------------------------------------------
variable "global_arguments" {
  description = "Global arguments for Traefik"
  type        = list(string)
  default     = []
}

variable "additional_arguments" {
  description = "Additional CLI arguments for Traefik"
  type        = list(string)
  default     = []
}

# Deployment Configuration
# -----------------------------------------------------------------------------
variable "deployment" {
  description = "Deployment configuration for Traefik"
  type = object({
    enabled               = bool
    kind                  = string
    replicas              = number
    pod_annotations       = map(string)
    pod_labels            = map(string)
    additional_containers = list(any)
  })
  default = {
    enabled               = true
    kind                  = "Deployment"
    replicas              = 2
    pod_annotations       = {}
    pod_labels            = {}
    additional_containers = []
  }
}

# Service Configuration
# -----------------------------------------------------------------------------
variable "service" {
  description = "Service configuration for Traefik"
  type = object({
    enabled     = bool
    type        = string
    annotations = map(string)
    labels      = map(string)
    spec        = map(any)
  })
  default = {
    enabled     = true
    type        = "LoadBalancer"
    annotations = {}
    labels      = {}
    spec        = {}
  }
}

# Ports Configuration
# -----------------------------------------------------------------------------
variable "ports" {
  description = "Port configuration for Traefik"
  type        = any
  default = {
    web = {
      port        = 80
      expose      = true
      exposedPort = 80
      protocol    = "TCP"
    }
    websecure = {
      port        = 443
      expose      = true
      exposedPort = 443
      protocol    = "TCP"
      tls = {
        enabled = true
      }
    }
    metrics = {
      port     = 9100
      expose   = false
      protocol = "TCP"
    }
  }
}

# IngressRoute Configuration
# -----------------------------------------------------------------------------
variable "ingress_route" {
  description = "IngressRoute configuration for Traefik dashboard"
  type        = any
  default = {
    dashboard = {
      enabled = false
    }
  }
}

# Traefik Providers Configuration
# -----------------------------------------------------------------------------
variable "traefik_providers" {
  description = "Traefik providers configuration (kubernetesCRD, kubernetesIngress)"
  type = object({
    kubernetes_crd = object({
      enabled                       = bool
      allow_cross_namespace         = bool
      allow_external_name_services  = bool
      namespaces                    = list(string)
    })
    kubernetes_ingress = object({
      enabled                       = bool
      allow_external_name_services  = bool
      namespaces                    = list(string)
      published_service_enabled     = bool
    })
  })
  default = {
    kubernetes_crd = {
      enabled                      = true
      allow_cross_namespace        = false
      allow_external_name_services = false
      namespaces                   = []
    }
    kubernetes_ingress = {
      enabled                      = true
      allow_external_name_services = false
      namespaces                   = []
      published_service_enabled    = true
    }
  }
}

# RBAC Configuration
# -----------------------------------------------------------------------------
variable "rbac" {
  description = "RBAC configuration for Traefik"
  type = object({
    enabled    = bool
    namespaced = bool
  })
  default = {
    enabled    = true
    namespaced = false
  }
}

# Service Account Configuration
# -----------------------------------------------------------------------------
variable "service_account" {
  description = "Service account configuration for Traefik"
  type = object({
    name = string
  })
  default = {
    name = "traefik"
  }
}

# Resource Limits
# -----------------------------------------------------------------------------
variable "resources" {
  description = "Resource limits and requests for Traefik"
  type        = any
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
  }
}

# Security Context
# -----------------------------------------------------------------------------
variable "security_context" {
  description = "Security context for Traefik container"
  type        = any
  default = {
    capabilities = {
      drop = ["ALL"]
      add  = ["NET_BIND_SERVICE"]
    }
    readOnlyRootFilesystem = true
    runAsGroup             = 65532
    runAsNonRoot           = true
    runAsUser              = 65532
  }
}

variable "pod_security_context" {
  description = "Pod security context for Traefik"
  type        = any
  default = {
    fsGroup             = 65532
    fsGroupChangePolicy = "OnRootMismatch"
  }
}

# Node Selection
# -----------------------------------------------------------------------------
variable "node_selector" {
  description = "Node selector for Traefik pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for Traefik pods"
  type        = list(any)
  default     = []
}

variable "affinity" {
  description = "Affinity rules for Traefik pods"
  type        = any
  default     = {}
}

# Persistence
# -----------------------------------------------------------------------------
variable "persistence" {
  description = "Persistence configuration for Traefik"
  type        = any
  default = {
    enabled = false
  }
}

# Observability
# -----------------------------------------------------------------------------
variable "logs" {
  description = "Logging configuration for Traefik"
  type        = any
  default = {
    general = {
      level = "INFO"
    }
    access = {
      enabled = true
    }
  }
}

variable "metrics" {
  description = "Metrics configuration for Traefik"
  type        = any
  default = {
    prometheus = {
      enabled     = true
      entryPoint  = "metrics"
      addEntryPointsLabels = true
      addRoutersLabels     = true
      addServicesLabels    = true
    }
  }
}

variable "tracing" {
  description = "Tracing configuration for Traefik"
  type        = any
  default     = {}
}

# Dashboard
# -----------------------------------------------------------------------------
variable "dashboard" {
  description = "Dashboard configuration for Traefik"
  type        = any
  default = {
    enabled   = true
    insecure  = false
  }
}

# Health Checks
# -----------------------------------------------------------------------------
variable "readiness_probe" {
  description = "Readiness probe configuration"
  type        = any
  default = {
    initialDelaySeconds = 2
    periodSeconds       = 10
    timeoutSeconds      = 2
    successThreshold    = 1
    failureThreshold    = 1
  }
}

variable "liveness_probe" {
  description = "Liveness probe configuration"
  type        = any
  default = {
    initialDelaySeconds = 2
    periodSeconds       = 10
    timeoutSeconds      = 2
    successThreshold    = 1
    failureThreshold    = 3
  }
}

# Module Configuration
# -----------------------------------------------------------------------------
variable "create_default_middleware" {
  description = "Whether to create default middleware configurations"
  type        = bool
  default     = false
}

variable "default_middlewares" {
  description = "Default middleware configurations to create"
  type        = any
  default     = {}
}

variable "tls_config" {
  description = "TLS configuration for Traefik"
  type = object({
    enabled             = bool
    stores              = optional(any, {})
    options             = optional(any, {})
    certificates        = optional(any, {})
    certificate_secrets = optional(any, {})
    servers_transports  = optional(any, {})
  })
  default = {
    enabled             = false
    stores              = {}
    options             = {}
    certificates        = {}
    certificate_secrets = {}
    servers_transports  = {}
  }
}

variable "create_ingress_routes" {
  description = "Whether to create IngressRoute resources"
  type        = bool
  default     = false
}

variable "ingress_routes" {
  description = "IngressRoute configurations"
  type = object({
    http  = any
    https = any
    tcp   = any
    udp   = any
  })
  default = {
    http  = {}
    https = {}
    tcp   = {}
    udp   = {}
  }
}
