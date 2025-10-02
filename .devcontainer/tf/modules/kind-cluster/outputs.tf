output "cluster_name" {
  description = "Name of the kind cluster"
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = kind_cluster.this.kubeconfig_path
}

output "endpoint" {
  description = "Kubernetes API endpoint"
  value       = kind_cluster.this.endpoint
}

output "client_certificate" {
  description = "Client certificate for authentication"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for authentication"
  value       = kind_cluster.this.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}

output "id" {
  description = "Cluster ID"
  value       = kind_cluster.this.id
}

output "kubeconfig" {
  description = "Kubeconfig content"
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}
