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

# Vault Issuer for cert-manager
# This configures cert-manager to use Vault's PKI engine for certificate issuance
# Uses the generic issuer submodule with Vault-specific configuration
module "mgmt_vault_issuer" {
  source = "./modules/cert-manager/modules/issuer"
  providers = {
    kubernetes = kubernetes.mgmt
    kubectl    = kubectl.mgmt
  }

  name                      = "vault-issuer"
  namespace                 = "cert-manager"
  is_cluster_issuer         = true  # Use ClusterIssuer so it can be referenced from any namespace
  create_service_account    = false  # Use existing SA from Helm chart
  service_account_name      = "cert-manager"
  create_token_request_role = true  # Still need token request RBAC for Vault auth

  issuer_spec = {
    vault = {
      server   = module.mgmt_vault.vault_addr
      path     = module.mgmt_vault.pki_sign_path
      caBundle = base64encode(module.mgmt_vault.ca_chain_pem)
      auth = {
        kubernetes = {
          role       = module.mgmt_vault.pki_kubernetes_auth_role
          mountPath  = "/v1/auth/${module.mgmt_vault.pki_kubernetes_auth_path}"
          serviceAccountRef = {
            name = "cert-manager"
          }
        }
      }
    }
  }

  labels = {
    "app.kubernetes.io/part-of" = "vault-integration"
  }

  depends_on = [module.mgmt_vault, module.mgmt_cert_manager]
}

# Vault Agent Injector TLS Certificate
# Certificate issued by Vault PKI via the vault-issuer
# See: https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
module "mgmt_vault_injector_certificate" {
  source = "./modules/cert-manager/modules/certificate"
  providers = {
    kubectl = kubectl.mgmt
  }

  name                = "injector-certificate"
  namespace           = "vault"
  secret_name         = "injector-tls"
  common_name         = "vault-agent-injector-svc.vault.svc.cluster.local"  # Must match allowed_domains
  generate_dns_names  = false  # Manually specify to match Vault PKI role restrictions
  dns_names = [
    # Only use full FQDN - short names not allowed by Vault PKI role
    "vault-agent-injector-svc.vault.svc.cluster.local"
  ]
  duration            = "2160h" # 90 days
  renew_before        = "360h"  # 15 days
  issuer_name         = module.mgmt_vault_issuer.name
  issuer_kind         = "ClusterIssuer"  # Must be ClusterIssuer since certificate is in different namespace

  labels = {
    "app.kubernetes.io/part-of" = "vault-integration"
  }

  component = "webhook-tls"

  depends_on = [module.mgmt_vault_issuer]
}

# Traefik Ingress Controller
# Deploys Traefik as the ingress controller for HTTP/HTTPS routing
module "mgmt_traefik" {
  source = "./modules/traefik"
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
    kubectl    = kubectl.mgmt
  }

  # Basic configuration
  namespace        = local.mgmt_cluster.traefik.namespace
  create_namespace = local.mgmt_cluster.traefik.create_namespace
  release_name     = local.mgmt_cluster.traefik.release_name
  chart_version    = local.mgmt_cluster.traefik.chart_version

  # Deployment configuration
  deployment = local.mgmt_cluster.traefik.deployment

  # Service configuration
  service = local.mgmt_cluster.traefik.service

  # Ports configuration
  ports = local.mgmt_cluster.traefik.ports

  # Traefik providers configuration (kubernetesCRD, kubernetesIngress)
  traefik_providers = local.mgmt_cluster.traefik.providers

  # Observability
  logs      = local.mgmt_cluster.traefik.logs
  metrics   = local.mgmt_cluster.traefik.metrics
  dashboard = local.mgmt_cluster.traefik.dashboard

  # Security contexts
  security_context     = local.mgmt_cluster.traefik.security_context
  pod_security_context = local.mgmt_cluster.traefik.pod_security_context

  # Resources
  resources = local.mgmt_cluster.traefik.resources

  # Module configurations (disabled for initial test)
  tls_config                = local.mgmt_cluster.traefik.tls_config
  create_default_middleware = local.mgmt_cluster.traefik.create_default_middleware
  default_middlewares       = local.mgmt_cluster.traefik.default_middlewares
  create_ingress_routes     = local.mgmt_cluster.traefik.create_ingress_routes
  ingress_routes            = local.mgmt_cluster.traefik.ingress_routes

  depends_on = [module.mgmt_cilium, module.mgmt_cert_manager, module.mgmt_vault]
}

