# metrics-server module outputs

output "helm_release_status" {
  description = "Status of the metrics-server Helm release"
  value       = helm_release.metrics_server.status
}

output "helm_release_version" {
  description = "Version of the deployed metrics-server Helm chart"
  value       = helm_release.metrics_server.version
}

output "namespace" {
  description = "Namespace where metrics-server is deployed"
  value       = helm_release.metrics_server.namespace
}

output "metrics_server_name" {
  description = "Name of the metrics-server Helm release"
  value       = helm_release.metrics_server.name
}