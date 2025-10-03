variable "registries" {
  description = "Map of registries to create proxies for"
  type = map(object({
    proxy_url = string
    port      = number
  }))
  default = {
    "docker.io" = {
      proxy_url = "https://registry-1.docker.io"
      port      = 5001
    }
    "gcr.io" = {
      proxy_url = "https://gcr.io"
      port      = 5002
    }
    "ghcr.io" = {
      proxy_url = "https://ghcr.io"
      port      = 5003
    }
    "quay.io" = {
      proxy_url = "https://quay.io"
      port      = 5004
    }
    "registry.k8s.io" = {
      proxy_url = "https://registry.k8s.io"
      port      = 5005
    }
  }
}

variable "cache_size_gb" {
  description = "Maximum cache size per registry in GB"
  type        = number
  default     = 10
}
