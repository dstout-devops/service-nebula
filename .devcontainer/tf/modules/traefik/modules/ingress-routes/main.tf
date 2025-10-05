# =============================================================================
# Traefik IngressRoute Submodule
# =============================================================================
# This module manages Traefik IngressRoute, IngressRouteTCP, and 
# IngressRouteUDP CRDs for routing traffic to services.

# HTTP IngressRoutes
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "ingress_route_http" {
  for_each = var.http_routes

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
      annotations = try(each.value.annotations, {})
    }
    spec = {
      entryPoints = each.value.entry_points
      routes      = each.value.routes
      tls         = try(each.value.tls, null)
    }
  })
}

# HTTPS IngressRoutes (with TLS)
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "ingress_route_https" {
  for_each = var.https_routes

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
      annotations = try(each.value.annotations, {})
    }
    spec = {
      entryPoints = each.value.entry_points
      routes      = each.value.routes
      tls = {
        secretName      = try(each.value.tls.secret_name, null)
        options         = try(each.value.tls.options, null)
        certResolver    = try(each.value.tls.cert_resolver, null)
        domains         = try(each.value.tls.domains, [])
        store           = try(each.value.tls.store, null)
      }
    }
  })
}

# TCP IngressRoutes
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "ingress_route_tcp" {
  for_each = var.tcp_routes

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRouteTCP"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
      annotations = try(each.value.annotations, {})
    }
    spec = {
      entryPoints = each.value.entry_points
      routes      = each.value.routes
      tls         = try(each.value.tls, null)
    }
  })
}

# UDP IngressRoutes
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "ingress_route_udp" {
  for_each = var.udp_routes

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRouteUDP"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
      annotations = try(each.value.annotations, {})
    }
    spec = {
      entryPoints = each.value.entry_points
      routes      = each.value.routes
    }
  })
}

# TraefikService (for weighted round robin, mirroring, etc.)
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "traefik_service" {
  for_each = var.traefik_services

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TraefikService"
    metadata = {
      name      = each.key
      namespace = var.namespace
      labels    = try(each.value.labels, {})
    }
    spec = {
      weighted  = try(each.value.weighted, null)
      mirroring = try(each.value.mirroring, null)
    }
  })
}
