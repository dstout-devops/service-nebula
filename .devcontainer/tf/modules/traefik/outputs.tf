# =============================================================================
# Traefik Module Outputs
# =============================================================================

# Namespace Information
# -----------------------------------------------------------------------------
output "namespace" {
  description = "The Kubernetes namespace where Traefik is deployed"
  value       = var.create_namespace ? kubernetes_namespace.traefik[0].metadata[0].name : var.namespace
}

# Helm Release Information
# -----------------------------------------------------------------------------
output "release_name" {
  description = "The name of the Helm release"
  value       = helm_release.traefik.name
}

output "release_version" {
  description = "The version of the Helm release"
  value       = helm_release.traefik.version
}

output "release_status" {
  description = "The status of the Helm release"
  value       = helm_release.traefik.status
}

# Service Information
# -----------------------------------------------------------------------------
output "service_name" {
  description = "The name of the Traefik service"
  value       = "${var.release_name}"
}

output "service_type" {
  description = "The type of the Traefik service"
  value       = var.service.type
}

# Ingress Class
# -----------------------------------------------------------------------------
output "ingress_class" {
  description = "The IngressClass name for Traefik"
  value       = var.release_name
}

# Dashboard Information
# -----------------------------------------------------------------------------
output "dashboard_enabled" {
  description = "Whether the Traefik dashboard is enabled"
  value       = try(var.dashboard.enabled, false)
}

# Metrics Information
# -----------------------------------------------------------------------------
output "metrics_enabled" {
  description = "Whether Prometheus metrics are enabled"
  value       = try(var.metrics.prometheus.enabled, false)
}

output "metrics_port" {
  description = "The port for Prometheus metrics"
  value       = try(var.ports.metrics.port, 9100)
}

# Submodule Outputs
# -----------------------------------------------------------------------------
output "middleware" {
  description = "Middleware configurations created by the middleware submodule"
  value       = var.create_default_middleware ? module.middleware[0] : null
}

output "tls" {
  description = "TLS configurations created by the TLS submodule"
  value       = var.tls_config.enabled ? module.tls[0] : null
}

output "ingress_routes" {
  description = "IngressRoutes created by the ingress-routes submodule"
  value       = var.create_ingress_routes ? module.ingress_routes[0] : null
}

# Ports Configuration
# -----------------------------------------------------------------------------
output "http_port" {
  description = "The HTTP port for Traefik"
  value       = try(var.ports.web.port, 80)
}

output "https_port" {
  description = "The HTTPS port for Traefik"
  value       = try(var.ports.websecure.port, 443)
}

# Provider Configuration
# -----------------------------------------------------------------------------
output "kubernetes_crd_enabled" {
  description = "Whether Kubernetes CRD provider is enabled"
  value       = var.traefik_providers.kubernetes_crd.enabled
}

output "kubernetes_ingress_enabled" {
  description = "Whether Kubernetes Ingress provider is enabled"
  value       = var.traefik_providers.kubernetes_ingress.enabled
}
