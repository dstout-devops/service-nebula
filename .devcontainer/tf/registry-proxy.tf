# ==============================================================================
# Container Registry Caching Infrastructure
# ==============================================================================
#
# This module deploys Docker Registry v2 containers as pull-through caches
# for common container registries. This significantly improves image pull
# performance and reduces external bandwidth usage.
#
# Architecture:
# 1. Registry proxies run in a dedicated Docker network (registry-proxies)
# 2. Kind cluster nodes connect to this network for direct container access
# 3. Containerd is configured with registry mirrors using the v2 config_path format
# 4. Registry configs are mounted into nodes at /etc/containerd/certs.d/
#
# Registries cached:
# - docker.io (Docker Hub)
# - gcr.io (Google Container Registry)
# - ghcr.io (GitHub Container Registry)
# - quay.io (Red Hat Quay)
# - registry.k8s.io (Kubernetes Registry)
#
# ==============================================================================

# Deploy registry proxy containers
module "registry_proxy" {
  source = "./modules/registry-proxy"
}

# Local configuration for registry mirrors
# This creates a map of registry hostnames to their proxy endpoints
locals {
  registry_mirrors = {
    "docker.io"       = "http://${module.registry_proxy.registry_ips["docker.io"]}:5000"
    "gcr.io"          = "http://${module.registry_proxy.registry_ips["gcr.io"]}:5000"
    "ghcr.io"         = "http://${module.registry_proxy.registry_ips["ghcr.io"]}:5000"
    "quay.io"         = "http://${module.registry_proxy.registry_ips["quay.io"]}:5000"
    "registry.k8s.io" = "http://${module.registry_proxy.registry_ips["registry.k8s.io"]}:5000"
  }
  
  # Containerd v2 configuration patch for registry caching
  # Uses config_path to enable per-registry configuration via certs.d/
  containerd_registry_config = <<-EOT
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
  EOT
}
