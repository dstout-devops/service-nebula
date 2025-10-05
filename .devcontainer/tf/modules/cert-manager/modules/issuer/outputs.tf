# cert-manager Issuer/ClusterIssuer Submodule Outputs

output "name" {
  description = "Name of the Issuer or ClusterIssuer"
  value       = var.name
}

output "namespace" {
  description = "Namespace of the Issuer (null for ClusterIssuer)"
  value       = var.is_cluster_issuer ? null : var.namespace
}

output "kind" {
  description = "Kind of issuer created (Issuer or ClusterIssuer)"
  value       = var.is_cluster_issuer ? "ClusterIssuer" : "Issuer"
}

output "service_account_name" {
  description = "Name of the ServiceAccount created (if any)"
  value       = var.create_service_account ? kubernetes_service_account.issuer[0].metadata[0].name : null
}

output "service_account_namespace" {
  description = "Namespace of the ServiceAccount created (if any)"
  value       = var.create_service_account ? kubernetes_service_account.issuer[0].metadata[0].namespace : null
}
