# =============================================================================
# TLS Submodule Outputs
# =============================================================================

output "tls_stores" {
  description = "Created TLS store names"
  value       = [for k, v in kubectl_manifest.tls_store : k]
}

output "tls_options" {
  description = "Created TLS option names"
  value       = [for k, v in kubectl_manifest.tls_option : k]
}

output "certificate_secrets" {
  description = "Created certificate secret names"
  value       = [for k, v in kubectl_manifest.certificate_secret : k]
}

output "certificates" {
  description = "Created cert-manager Certificate names"
  value       = [for k, v in kubectl_manifest.certificate : k]
}

output "servers_transports" {
  description = "Created ServersTransport names"
  value       = [for k, v in kubectl_manifest.servers_transport : k]
}

output "all_resources" {
  description = "All created TLS resource names"
  value = {
    tls_stores          = [for k, v in kubectl_manifest.tls_store : k]
    tls_options         = [for k, v in kubectl_manifest.tls_option : k]
    certificate_secrets = [for k, v in kubectl_manifest.certificate_secret : k]
    certificates        = [for k, v in kubectl_manifest.certificate : k]
    servers_transports  = [for k, v in kubectl_manifest.servers_transport : k]
  }
}
