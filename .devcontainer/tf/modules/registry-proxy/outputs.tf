output "registry_mirrors" {
  description = "Map of registry mirrors for containerd configuration"
  value = {
    for registry, config in var.registries : registry => {
      endpoint = ["http://host.docker.internal:${config.port}"]
    }
  }
}

output "containerd_config_patch" {
  description = "Containerd config patch for Kind cluster"
  value = yamlencode({
    "containerdConfigPatches" = [
      <<-EOT
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
          ${join("\n  ", [for registry, config in var.registries : <<-MIRROR
          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${registry}"]
            endpoint = ["http://host.docker.internal:${config.port}"]
          MIRROR
  ])}
      EOT
]
})
}

output "proxy_status" {
  description = "Registry proxy container names and ports"
  value = {
    for registry, config in var.registries : registry => {
      container_name = docker_container.registry_proxy[registry].name
      port           = config.port
      health_url     = "http://127.0.0.1:${config.port}/v2/"
    }
  }
}

output "network_name" {
  description = "Name of the Docker network for registry proxies"
  value       = docker_network.registry_network.name
}

output "registry_ips" {
  description = "Map of registry names to their container IP addresses"
  value = {
    for registry, container in docker_container.registry_proxy : registry => container.network_data[0].ip_address
  }
}
