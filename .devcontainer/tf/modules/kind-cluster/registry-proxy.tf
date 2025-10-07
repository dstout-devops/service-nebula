# Registry mirror configuration files for containerd
# Note: Directories are pre-created by setup_env.sh under /tmp/registry-cache
# These hosts.toml files tell containerd to use the registry proxy containers

resource "local_file" "registry_mirror_configs" {
  for_each = var.registry_mirrors

  filename = "/tmp/registry-cache/config/${each.key}/hosts.toml"
  content  = <<-EOT
    server = "https://${each.key}"
    
    [host."${each.value}"]
      capabilities = ["pull", "resolve"]
  EOT

  # Ensure parent directory exists - local_file will create it with proper permissions
  directory_permission = "0755"
  file_permission      = "0644"
}

# Connect Kind nodes to registry network after cluster is created
resource "null_resource" "connect_to_registry_network" {
  for_each = var.registry_network != null ? toset(concat(
    ["${var.cluster_name}-control-plane"],
    [for i in range(var.worker_count) : "${var.cluster_name}-worker${i > 0 ? i + 1 : ""}"]
  )) : toset([])

  depends_on = [kind_cluster.this]

  provisioner "local-exec" {
    command = "docker network connect ${var.registry_network} ${each.key} 2>/dev/null || true"
  }
}
