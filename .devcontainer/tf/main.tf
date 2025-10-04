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
  registry_network          = module.registry_proxy.network_name
  registry_mirrors          = local.registry_mirrors
  containerd_config_patches = [local.containerd_registry_config]

  depends_on = [module.registry_proxy]
}

module "mgmt_cilium" {
  source = "./modules/cilium"
  providers = {
    helm = helm.mgmt
  }

  cluster_name = module.mgmt_cluster.cluster_name
  namespace    = var.global_config.default_namespace
  cluster_id   = local.mgmt_cluster.cilium.cluster_id

  cilium_version = local.mgmt_cluster.cilium.version
  ipam_mode      = local.mgmt_cluster.cilium.ipam_mode

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

module "mgmt_cert_manager" {
  source = "./modules/cert-manager"
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
  }

  cluster_name     = module.mgmt_cluster.cluster_name
  namespace        = "cert-manager"
  chart_version    = "v1.18.2"
  install_crds     = true
  create_namespace = true

  # Controller configuration
  controller = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "256Mi"
        cpu    = "500m"
      }
    }
  }

  # Webhook configuration
  webhook = {
    replicas        = 1
    timeout_seconds = 10
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "64Mi"
        cpu    = "100m"
      }
    }
  }

  # CA Injector configuration
  cainjector = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "128Mi"
        cpu    = "100m"
      }
    }
  }

  # Global configuration
  global = {
    log_level = 2
  }

  # Feature flags
  features = {
    prometheus      = true
    startupapicheck = true
    feature_gates   = ""
  }

  # Vault Issuer and Injector TLS will be configured after Vault is deployed
  # This is done in a separate config block below

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

  # Object-based configuration
  tls        = local.mgmt_cluster.vault.tls
  tls_config = local.mgmt_cluster.vault.tls_config
  pki_engine = local.mgmt_cluster.vault.pki_engine
  storage    = local.mgmt_cluster.vault.storage

  # Vault Agent Injector with cert-manager TLS and HA
  injector = {
    enabled          = true
    replicas         = 2
    leader_elector   = true
    use_cert_manager = true
    tls_secret_name  = "injector-tls"
    webhook_annotations = {
      "cert-manager.io/inject-ca-from" = "vault/injector-certificate"
    }
  }

  # Note: PKI engine configuration is now handled by pki_engine variable above
  # No need for separate cert_manager_integration block

  depends_on = [module.mgmt_cilium, module.mgmt_cert_manager]
}

# cert-manager Vault Issuer and Injector Certificate
# This configures cert-manager to use Vault's PKI engine for certificate issuance
# Deployed after Vault is up and PKI is configured
module "mgmt_cert_manager_vault_issuer" {
  source = "./modules/cert-manager"
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
    kubectl    = kubectl.mgmt
  }

  cluster_name     = module.mgmt_cluster.cluster_name
  namespace        = "cert-manager"
  chart_version    = "v1.18.2"
  install_crds     = false # Already installed
  create_namespace = false # Already exists

  # Controller configuration - use same as initial deployment
  controller = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "256Mi"
        cpu    = "500m"
      }
    }
  }

  # Webhook configuration
  webhook = {
    replicas        = 1
    timeout_seconds = 10
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "64Mi"
        cpu    = "100m"
      }
    }
  }

  # CA Injector configuration
  cainjector = {
    replicas = 1
    resources = {
      requests = {
        memory = "32Mi"
        cpu    = "10m"
      }
      limits = {
        memory = "128Mi"
        cpu    = "100m"
      }
    }
  }

  # Global configuration
  global = {
    log_level = 2
  }

  # Feature flags
  features = {
    prometheus      = true
    startupapicheck = false # Skip startup check on second apply
    feature_gates   = ""
  }

  # Vault Issuer Configuration
  # Uses Vault's PKI secrets engine to issue certificates
  vault_issuer = {
    enabled         = true
    name            = "vault-issuer"
    vault_server    = module.mgmt_vault.vault_addr
    vault_ca_bundle = base64encode(module.mgmt_vault.ca_chain_pem) # Full chain for TLS verification
    pki_path        = module.mgmt_vault.pki_sign_path
    auth = {
      role         = module.mgmt_vault.pki_kubernetes_auth_role
      mount_path   = "/v1/auth/${module.mgmt_vault.pki_kubernetes_auth_path}"
      sa_name      = "cert-manager" # Use cert-manager SA (matches PKI auth role)
      sa_namespace = "cert-manager" # In cert-manager namespace
      audiences    = []
    }
  }

  # Vault Injector TLS Certificate
  # Certificate issued by Vault PKI via the vault-issuer
  # See: https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
  vault_injector_tls = {
    enabled      = true
    namespace    = "vault"
    service_name = "vault-agent-injector-svc"
    secret_name  = "injector-tls"
    issuer_name  = "vault-issuer" # References the Vault Issuer
    duration     = "2160h"        # 90 days
    renew_before = "360h"         # 15 days
    dns_names    = []             # Uses defaults from module
  }

  depends_on = [module.mgmt_vault]
}

