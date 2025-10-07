resource "kind_cluster" "this" {
  name            = var.cluster_name
  kubeconfig_path = pathexpand(var.kubeconfig_path)

  # Ensure registry configs exist before creating cluster
  depends_on = [local_file.registry_mirror_configs]

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Networking configuration
    dynamic "networking" {
      for_each = var.pod_subnet != null || var.service_subnet != null || var.disable_default_cni ? [1] : []
      content {
        pod_subnet          = var.pod_subnet
        service_subnet      = var.service_subnet
        kube_proxy_mode     = var.kube_proxy_mode
        disable_default_cni = var.disable_default_cni
      }
    }

    # Containerd configuration patches (e.g., for registry mirrors)
    containerd_config_patches = var.containerd_config_patches

    # Control plane nodes
    dynamic "node" {
      for_each = range(var.control_plane_count)
      content {
        role = "control-plane"

        # Mount host CA certificates
        dynamic "extra_mounts" {
          for_each = var.mount_host_ca_certs ? [1] : []
          content {
            host_path      = "/etc/ssl/certs/ca-certificates.crt"
            container_path = "/etc/ssl/certs/ca-certificates.crt"
            read_only      = true
          }
        }

        # Mount registry mirror configs
        dynamic "extra_mounts" {
          for_each = var.registry_mirrors
          content {
            host_path      = "/tmp/registry-cache/config/${extra_mounts.key}"
            container_path = "/etc/containerd/certs.d/${extra_mounts.key}"
            read_only      = true
          }
        }

        # Add extra port mappings if provided or if ingress is enabled
        dynamic "extra_port_mappings" {
          for_each = var.enable_ingress ? [
            { container_port = 80, host_port = 80, protocol = "TCP" },
            { container_port = 443, host_port = 443, protocol = "TCP" }
          ] : []
          content {
            container_port = extra_port_mappings.value.container_port
            host_port      = extra_port_mappings.value.host_port
            protocol       = extra_port_mappings.value.protocol
          }
        }

        dynamic "extra_port_mappings" {
          for_each = var.extra_port_mappings
          content {
            container_port = extra_port_mappings.value.container_port
            host_port      = extra_port_mappings.value.host_port
            protocol       = extra_port_mappings.value.protocol
          }
        }
      }
    }

    # Worker nodes
    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"

        # Mount host CA certificates
        dynamic "extra_mounts" {
          for_each = var.mount_host_ca_certs ? [1] : []
          content {
            host_path      = "/etc/ssl/certs/ca-certificates.crt"
            container_path = "/etc/ssl/certs/ca-certificates.crt"
            read_only      = true
          }
        }

        # Mount registry mirror configs
        dynamic "extra_mounts" {
          for_each = var.registry_mirrors
          content {
            host_path      = "/tmp/registry-cache/config/${extra_mounts.key}"
            container_path = "/etc/containerd/certs.d/${extra_mounts.key}"
            read_only      = true
          }
        }
      }
    }
  }
}

