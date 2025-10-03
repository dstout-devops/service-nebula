# Management cluster - created first as the foundation
# Network: 10.0.0.0/16 (pods), 10.1.0.0/16 (services)
module "mgmt_cluster" {
  source = "./modules/kind-cluster"

  cluster_name        = "mgmt"
  control_plane_count = 1
  worker_count        = 3
  enable_ingress      = false

  pod_subnet          = "10.250.0.0/16"
  service_subnet      = "10.251.0.0/16"
  disable_default_cni = true
  kube_proxy_mode     = "nftables"
  mount_host_ca_certs = true
}

# Install Cilium CNI on management cluster
module "mgmt_cilium" {
  source = "./modules/cilium"

  cluster_name     = module.mgmt_cluster.cluster_name
  cluster_id       = 1
  kubeconfig_path  = module.mgmt_cluster.kubeconfig_path

  cilium_version    = "1.18.2"
  ipam_mode         = "kubernetes"

  enable_hubble    = true
  enable_hubble_ui = true

  # Use the aliased helm provider configured for mgmt cluster
  providers = {
    helm = helm.mgmt
  }

  depends_on = [module.mgmt_cluster]
}

# Future clusters can be added here with dependencies
# Example workload cluster with non-overlapping networks:
# Network: 10.2.0.0/16 (pods), 10.3.0.0/16 (services)
#
# module "workload_cluster" {
#   source = "./modules/kind-cluster"
#
#   cluster_name        = "workload"
#   control_plane_count = 1
#   worker_count        = 2
#   enable_ingress      = true
#
#   pod_subnet          = "10.2.0.0/16"
#   service_subnet      = "10.3.0.0/16"
#   disable_default_cni = true
#   mount_host_ca_certs = true
#
#   depends_on = [module.mgmt_cluster]
# }
#
# module "workload_cilium" {
#   source = "./modules/cilium"
#
#   cluster_name = module.workload_cluster.cluster_name
#   cluster_id   = 2
#   kubeconfig   = module.workload_cluster.kubeconfig
#
#   enable_hubble    = true
#   enable_hubble_ui = true
#
#   depends_on = [module.workload_cluster]
# }
#
# Network allocation plan for cluster mesh:
# Cluster 1 (mgmt):     ID=1, 10.0.0.0/16 (pods), 10.1.0.0/16 (services)
# Cluster 2 (workload): ID=2, 10.2.0.0/16 (pods), 10.3.0.0/16 (services)
# Cluster 3:            ID=3, 10.4.0.0/16 (pods), 10.5.0.0/16 (services)
# Cluster 4:            ID=4, 10.6.0.0/16 (pods), 10.7.0.0/16 (services)
