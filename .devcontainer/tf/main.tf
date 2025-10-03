locals {
  mgmt_cluster = var.clusters.mgmt
}

# Management cluster - created first as the foundation
module "mgmt_cluster" {
  source          = "./modules/kind-cluster"
  kubeconfig_path = var.global_config.kubeconfig_path

  cluster_name        = "mgmt"
  control_plane_count = local.mgmt_cluster.control_plane_count
  worker_count        = local.mgmt_cluster.worker_count
  enable_ingress      = local.mgmt_cluster.enable_ingress

  pod_subnet          = local.mgmt_cluster.pod_subnet
  service_subnet      = local.mgmt_cluster.service_subnet
  disable_default_cni = local.mgmt_cluster.disable_default_cni
  kube_proxy_mode     = local.mgmt_cluster.kube_proxy_mode
  mount_host_ca_certs = local.mgmt_cluster.mount_host_ca_certs
  
  # Registry caching configuration (see registry-cache.tf)
  registry_network              = module.registry_proxy.network_name
  registry_mirrors              = local.registry_mirrors
  containerd_config_patches     = [local.containerd_registry_config]
  
  depends_on = [module.registry_proxy]
}

module "mgmt_cilium" {
  source = "./modules/cilium"
  providers = {
    helm = helm.mgmt
  }

  cluster_name     = module.mgmt_cluster.cluster_name
  namespace        = var.global_config.default_namespace
  cluster_id       = local.mgmt_cluster.cilium.cluster_id

  cilium_version    = local.mgmt_cluster.cilium.version
  ipam_mode         = local.mgmt_cluster.cilium.ipam_mode

  enable_hubble    = local.mgmt_cluster.cilium.enable_hubble
  enable_hubble_ui = local.mgmt_cluster.cilium.enable_hubble_ui

  depends_on = [module.mgmt_cluster]
}

module "mgmt_metrics_server" {
  source = "./modules/metrics-server"
  providers = {
    helm = helm.mgmt
  }

  cluster_name           = module.mgmt_cluster.cluster_name
  namespace              = var.global_config.default_namespace
  metrics_server_version = local.mgmt_cluster.metrics_server.version
  replicas               = local.mgmt_cluster.metrics_server.replicas

  depends_on = [module.mgmt_cilium]
}

module "mgmt_vault" {
  source = "./modules/vault"
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
  }

  cluster_name    = module.mgmt_cluster.cluster_name
  namespace       = "vault"
  deployment_mode = local.mgmt_cluster.vault.deployment_mode
  vault_version   = local.mgmt_cluster.vault.version
  enable_ui       = local.mgmt_cluster.vault.enable_ui
  ha_replicas     = local.mgmt_cluster.vault.ha_replicas

  depends_on = [module.mgmt_cilium]
}
