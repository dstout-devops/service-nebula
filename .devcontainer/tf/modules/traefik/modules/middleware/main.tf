# =============================================================================
# Traefik Middleware Submodule
# =============================================================================
# This module manages Traefik Middleware CRDs for HTTP request/response
# processing, including headers, rate limiting, authentication, etc.

# Headers Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "headers" {
  for_each = var.headers_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      headers = each.value.config
    }
  })
}

# Rate Limiting Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "rate_limit" {
  for_each = var.rate_limit_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      rateLimit = each.value.config
    }
  })
}

# Retry Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "retry" {
  for_each = var.retry_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      retry = each.value.config
    }
  })
}

# Circuit Breaker Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "circuit_breaker" {
  for_each = var.circuit_breaker_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      circuitBreaker = each.value.config
    }
  })
}

# Basic Auth Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "basic_auth" {
  for_each = var.basic_auth_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      basicAuth = each.value.config
    }
  })
}

# Forward Auth Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "forward_auth" {
  for_each = var.forward_auth_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      forwardAuth = each.value.config
    }
  })
}

# IP Whitelist Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "ip_whitelist" {
  for_each = var.ip_whitelist_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      ipWhiteList = each.value.config
    }
  })
}

# Redirect Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "redirect" {
  for_each = var.redirect_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      redirectScheme = each.value.config
    }
  })
}

# Strip Prefix Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "strip_prefix" {
  for_each = var.strip_prefix_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      stripPrefix = each.value.config
    }
  })
}

# Compress Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "compress" {
  for_each = var.compress_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      compress = each.value.config
    }
  })
}

# Chain Middleware
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "chain" {
  for_each = var.chain_middlewares

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      chain = {
        middlewares = each.value.middlewares
      }
    }
  })

  depends_on = [
    kubectl_manifest.headers,
    kubectl_manifest.rate_limit,
    kubectl_manifest.retry,
    kubectl_manifest.circuit_breaker,
    kubectl_manifest.basic_auth,
    kubectl_manifest.forward_auth,
    kubectl_manifest.ip_whitelist,
    kubectl_manifest.redirect,
    kubectl_manifest.strip_prefix,
    kubectl_manifest.compress
  ]
}
