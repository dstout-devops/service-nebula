# =============================================================================
# IngressRoute Submodule Outputs
# =============================================================================

output "http_routes" {
  description = "Created HTTP IngressRoute names"
  value       = [for k, v in kubectl_manifest.ingress_route_http : k]
}

output "https_routes" {
  description = "Created HTTPS IngressRoute names"
  value       = [for k, v in kubectl_manifest.ingress_route_https : k]
}

output "tcp_routes" {
  description = "Created TCP IngressRoute names"
  value       = [for k, v in kubectl_manifest.ingress_route_tcp : k]
}

output "udp_routes" {
  description = "Created UDP IngressRoute names"
  value       = [for k, v in kubectl_manifest.ingress_route_udp : k]
}

output "traefik_services" {
  description = "Created TraefikService names"
  value       = [for k, v in kubectl_manifest.traefik_service : k]
}

output "all_routes" {
  description = "All created IngressRoute names by type"
  value = {
    http            = [for k, v in kubectl_manifest.ingress_route_http : k]
    https           = [for k, v in kubectl_manifest.ingress_route_https : k]
    tcp             = [for k, v in kubectl_manifest.ingress_route_tcp : k]
    udp             = [for k, v in kubectl_manifest.ingress_route_udp : k]
    traefik_services = [for k, v in kubectl_manifest.traefik_service : k]
  }
}
