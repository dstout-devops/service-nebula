# Output from Init Submodule

output "init_complete" {
  description = "Indicates initialization is complete"
  value       = true
  depends_on  = [kubernetes_job.vault_init_job]
}

output "credentials_location" {
  description = "Location of Vault credentials"
  value       = "Credentials stored in Kubernetes secret: ${var.unseal_keys_secret_name} (namespace: ${var.namespace})"
}

output "job_name" {
  description = "Name of the Vault initialization job"
  value       = kubernetes_job.vault_init_job.metadata[0].name
}

output "configmap_name" {
  description = "Name of the ConfigMap containing the init script"
  value       = kubernetes_config_map.vault_init_script.metadata[0].name
}
