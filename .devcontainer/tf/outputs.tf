# Management cluster outputs
output "mgmt_cluster_name" {
  description = "Name of the management cluster"
  value       = module.mgmt_cluster.cluster_name
}

output "mgmt_kubeconfig_path" {
  description = "Path to the management cluster kubeconfig file"
  value       = module.mgmt_cluster.kubeconfig_path
}

output "mgmt_endpoint" {
  description = "Management cluster Kubernetes API endpoint"
  value       = module.mgmt_cluster.endpoint
}

output "mgmt_cluster_id" {
  description = "Management cluster ID"
  value       = module.mgmt_cluster.id
}

# Summary output for convenience
output "clusters" {
  description = "Summary of all clusters"
  value = {
    mgmt = {
      name     = module.mgmt_cluster.cluster_name
      endpoint = module.mgmt_cluster.endpoint
    }
  }
}
