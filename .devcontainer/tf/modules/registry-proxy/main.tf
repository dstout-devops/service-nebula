# Container Registry Proxy/Mirror Module
# Deploys registry proxy containers and configures containerd to use them
# Reduces network load and improves image pull performance

# Docker network for registry proxies
resource "docker_network" "registry_network" {
  name   = var.network_name
  driver = "bridge"

  ipam_config {
    subnet  = var.subnet
    gateway = var.gateway
  }
}

# Registry proxy containers
# Note: Cache directories are pre-created by setup_env.sh with correct permissions
resource "docker_container" "registry_proxy" {
  for_each = var.registries

  name  = "registry-proxy-${replace(each.key, ".", "-")}"
  image = "registry:2"

  restart = "unless-stopped"

  # Wait for container to be healthy before considering it created
  wait         = true
  wait_timeout = 60

  # Run as vscode user (UID 1000) to match devcontainer permissions
  user = "1000:1000"

  networks_advanced {
    name = docker_network.registry_network.name
  }

  ports {
    internal = 5000
    external = each.value.port
    ip       = "127.0.0.1"
  }

  env = [
    "REGISTRY_PROXY_REMOTEURL=${each.value.proxy_url}",
    "REGISTRY_STORAGE_DELETE_ENABLED=true",
    "REGISTRY_HTTP_ADDR=0.0.0.0:5000",
    "REGISTRY_PROXY_REMOTEURL_SKIPVERIFY=true"
  ]

  volumes {
    host_path      = "/tmp/registry-cache/${replace(each.key, ".", "-")}"
    container_path = "/var/lib/registry"
  }

  volumes {
    host_path      = "/etc/ssl/certs/ca-certificates.crt"
    container_path = "/etc/ssl/certs/ca-certificates.crt"
    read_only      = true
  }

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost:5000/v2/"]
    interval = "30s"
    timeout  = "3s"
    retries  = 3
  }

  labels {
    label = "com.service-nebula.component"
    value = "registry-proxy"
  }

  labels {
    label = "com.service-nebula.registry"
    value = each.key
  }
}
