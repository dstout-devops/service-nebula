# =============================================================================
# IngressRoute Submodule Variables
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace for IngressRoute resources"
  type        = string
}

# HTTP IngressRoutes
# -----------------------------------------------------------------------------
variable "http_routes" {
  description = "Map of HTTP IngressRoute configurations"
  type = map(object({
    labels       = optional(map(string))
    annotations  = optional(map(string))
    entry_points = list(string)
    routes = list(object({
      match = string
      kind  = string
      services = list(object({
        name      = string
        port      = number
        namespace = optional(string)
        weight    = optional(number)
        scheme    = optional(string)
        sticky    = optional(object({
          cookie = object({
            name     = string
            secure   = optional(bool)
            httpOnly = optional(bool)
            sameSite = optional(string)
          })
        }))
      }))
      middlewares = optional(list(object({
        name      = string
        namespace = optional(string)
      })))
      priority = optional(number)
    }))
    tls = optional(any)
  }))
  default = {}
}

# HTTPS IngressRoutes
# -----------------------------------------------------------------------------
variable "https_routes" {
  description = "Map of HTTPS IngressRoute configurations"
  type = map(object({
    labels       = optional(map(string))
    annotations  = optional(map(string))
    entry_points = list(string)
    routes = list(object({
      match = string
      kind  = string
      services = list(object({
        name      = string
        port      = number
        namespace = optional(string)
        weight    = optional(number)
        scheme    = optional(string)
        sticky    = optional(object({
          cookie = object({
            name     = string
            secure   = optional(bool)
            httpOnly = optional(bool)
            sameSite = optional(string)
          })
        }))
      }))
      middlewares = optional(list(object({
        name      = string
        namespace = optional(string)
      })))
      priority = optional(number)
    }))
    tls = object({
      secret_name   = optional(string)
      options       = optional(object({
        name      = string
        namespace = optional(string)
      }))
      cert_resolver = optional(string)
      domains = optional(list(object({
        main = string
        sans = optional(list(string))
      })))
      store = optional(object({
        name      = string
        namespace = optional(string)
      }))
    })
  }))
  default = {}
}

# TCP IngressRoutes
# -----------------------------------------------------------------------------
variable "tcp_routes" {
  description = "Map of TCP IngressRoute configurations"
  type = map(object({
    labels       = optional(map(string))
    annotations  = optional(map(string))
    entry_points = list(string)
    routes = list(object({
      match = string
      services = list(object({
        name      = string
        port      = number
        namespace = optional(string)
        weight    = optional(number)
        terminationDelay = optional(number)
        proxyProtocol = optional(object({
          version = number
        }))
      }))
      middlewares = optional(list(object({
        name      = string
        namespace = optional(string)
      })))
      priority = optional(number)
    }))
    tls = optional(object({
      secretName   = optional(string)
      passthrough  = optional(bool)
      options      = optional(object({
        name      = string
        namespace = optional(string)
      }))
      certResolver = optional(string)
      domains = optional(list(object({
        main = string
        sans = optional(list(string))
      })))
    }))
  }))
  default = {}
}

# UDP IngressRoutes
# -----------------------------------------------------------------------------
variable "udp_routes" {
  description = "Map of UDP IngressRoute configurations"
  type = map(object({
    labels       = optional(map(string))
    annotations  = optional(map(string))
    entry_points = list(string)
    routes = list(object({
      services = list(object({
        name      = string
        port      = number
        namespace = optional(string)
        weight    = optional(number)
      }))
    }))
  }))
  default = {}
}

# TraefikService
# -----------------------------------------------------------------------------
variable "traefik_services" {
  description = "Map of TraefikService configurations for advanced load balancing"
  type = map(object({
    labels = optional(map(string))
    weighted = optional(object({
      services = list(object({
        name      = string
        port      = number
        weight    = number
        namespace = optional(string)
      }))
      sticky = optional(object({
        cookie = object({
          name     = string
          secure   = optional(bool)
          httpOnly = optional(bool)
          sameSite = optional(string)
        })
      }))
    }))
    mirroring = optional(object({
      name      = string
      port      = number
      namespace = optional(string)
      mirrors = list(object({
        name      = string
        port      = number
        percent   = number
        namespace = optional(string)
      }))
    }))
  }))
  default = {}
}
