variable "global_config" {
  description = "Global configuration options"
  type = object({
    default_namespace = string
    kubeconfig_path   = string
  })
  
  default = {
    default_namespace = "kube-system"
    kubeconfig_path   = "~/.kube/config"
  }
}

variable "clusters" {
  description = "Cluster configurations"
  type = map(object({
    # Kind cluster configuration
    worker_count         = number
    control_plane_count  = number
    enable_ingress      = bool
    pod_subnet          = string
    service_subnet      = string
    kube_proxy_mode     = string
    disable_default_cni = bool
    mount_host_ca_certs = bool
    
    # Cilium configuration
    cilium = object({
      version    = string
      cluster_id = number
      ipam_mode  = string
      enable_hubble     = bool
      enable_hubble_ui  = bool
    })
    
    # Metrics-server configuration
    metrics_server = object({
      version  = string
      replicas = number
    })
    
    # Vault configuration
    vault = object({
      deployment_mode = string
      version        = string
      enable_ui      = bool
      ha_replicas    = number
    })
  }))
  
  default = {
    mgmt = {
      worker_count         = 3
      control_plane_count  = 1
      enable_ingress      = false
      pod_subnet          = "10.250.0.0/16"
      service_subnet      = "10.251.0.0/16"
      kube_proxy_mode     = "nftables"
      disable_default_cni = true
      mount_host_ca_certs = true
      
      cilium = {
        version    = "1.18.2"
        cluster_id = 250
        ipam_mode  = "kubernetes"
        enable_hubble     = true
        enable_hubble_ui  = true
      }
      
      metrics_server = {
        version  = "3.13.0"
        replicas = 1
      }
      
      vault = {
        deployment_mode = "standalone"  # Options: standalone, standalone-tls, ha-raft, ha-raft-tls
        version        = "0.31.0"
        enable_ui      = true
        ha_replicas    = 3
      }
    }
  }
}
