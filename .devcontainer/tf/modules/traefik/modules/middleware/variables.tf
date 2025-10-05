# =============================================================================
# Middleware Submodule Variables
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace for middleware resources"
  type        = string
}

# Headers Middleware
# -----------------------------------------------------------------------------
variable "headers_middlewares" {
  description = "Map of headers middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Rate Limit Middleware
# -----------------------------------------------------------------------------
variable "rate_limit_middlewares" {
  description = "Map of rate limit middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Retry Middleware
# -----------------------------------------------------------------------------
variable "retry_middlewares" {
  description = "Map of retry middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Circuit Breaker Middleware
# -----------------------------------------------------------------------------
variable "circuit_breaker_middlewares" {
  description = "Map of circuit breaker middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Basic Auth Middleware
# -----------------------------------------------------------------------------
variable "basic_auth_middlewares" {
  description = "Map of basic auth middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Forward Auth Middleware
# -----------------------------------------------------------------------------
variable "forward_auth_middlewares" {
  description = "Map of forward auth middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# IP Whitelist Middleware
# -----------------------------------------------------------------------------
variable "ip_whitelist_middlewares" {
  description = "Map of IP whitelist middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Redirect Middleware
# -----------------------------------------------------------------------------
variable "redirect_middlewares" {
  description = "Map of redirect middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Strip Prefix Middleware
# -----------------------------------------------------------------------------
variable "strip_prefix_middlewares" {
  description = "Map of strip prefix middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Compress Middleware
# -----------------------------------------------------------------------------
variable "compress_middlewares" {
  description = "Map of compress middleware configurations"
  type = map(object({
    labels = optional(map(string))
    config = any
  }))
  default = {}
}

# Chain Middleware
# -----------------------------------------------------------------------------
variable "chain_middlewares" {
  description = "Map of chain middleware configurations"
  type = map(object({
    labels      = optional(map(string))
    middlewares = list(object({
      name      = string
      namespace = optional(string)
    }))
  }))
  default = {}
}
