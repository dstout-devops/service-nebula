# cert-manager Certificate Submodule Outputs

output "name" {
  description = "Name of the Certificate resource"
  value       = var.name
}

output "namespace" {
  description = "Namespace of the Certificate resource"
  value       = var.namespace
}

output "secret_name" {
  description = "Name of the Kubernetes secret containing the certificate"
  value       = var.secret_name
}

output "issuer_name" {
  description = "Name of the Issuer or ClusterIssuer used"
  value       = var.issuer_name
}

output "issuer_kind" {
  description = "Kind of issuer used (Issuer or ClusterIssuer)"
  value       = var.issuer_kind
}

output "common_name" {
  description = "Common name of the certificate"
  value       = var.common_name
}

output "dns_names" {
  description = "DNS names (SANs) in the certificate"
  value       = length(var.dns_names) > 0 ? var.dns_names : (
    var.generate_dns_names ? [
      var.service_name,
      "${var.service_name}.${var.namespace}",
      "${var.service_name}.${var.namespace}.svc",
      "${var.service_name}.${var.namespace}.svc.cluster.local"
    ] : []
  )
}
