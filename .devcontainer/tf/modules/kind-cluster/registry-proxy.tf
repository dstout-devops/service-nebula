
# Ensure registry directory exists with proper permissions
resource "null_resource" "registry_dir" {
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p /tmp/kind-registry-${var.cluster_name}
      chmod 777 /tmp/kind-registry-${var.cluster_name}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf /tmp/kind-registry-${self.triggers.cluster_name} || true"
  }
}

# Create subdirectories for each registry mirror with proper permissions
resource "null_resource" "registry_mirror_dirs" {
  for_each = var.registry_mirrors

  depends_on = [null_resource.registry_dir]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p /tmp/kind-registry-${var.cluster_name}/${each.key}
      chmod 777 /tmp/kind-registry-${var.cluster_name}/${each.key}
    EOT
  }
}

# Create local directory with registry mirror configs (before cluster creation)
resource "local_file" "registry_mirror_configs" {
  for_each = var.registry_mirrors

  filename = "/tmp/kind-registry-${var.cluster_name}/${each.key}/hosts.toml"
  content  = <<-EOT
    server = "https://${each.key}"
    
    [host."${each.value}"]
      capabilities = ["pull", "resolve"]
  EOT

  depends_on = [null_resource.registry_mirror_dirs]
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
