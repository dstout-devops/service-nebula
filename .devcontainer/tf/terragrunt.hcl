# =============================================================================
# Terragrunt Root Configuration
# Provides centralized configuration for OpenTofu/Terraform management
# =============================================================================

# Use OpenTofu instead of Terraform
terraform_binary = "tofu"

# Configure OpenTofu version constraint
terraform_version_constraint = ">= 1.10.0"

# Configure remote state (using local backend for dev, can be changed for prod)
remote_state {
  backend = "local"
  
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "providers_generated.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_providers {
        docker = {
          source  = "kreuzwerker/docker"
          version = "~> 3.0"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 3.0"
        }
        kind = {
          source  = "tehcyx/kind"
          version = "~> 0.9"
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = "~> 1.19"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.0"
        }
        local = {
          source  = "hashicorp/local"
          version = "~> 2.0"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.0"
        }
        tls = {
          source  = "hashicorp/tls"
          version = "~> 4.0"
        }
        vault = {
          source  = "hashicorp/vault"
          version = "~> 5.0"
        }
      }
    }

    provider "docker" {
      host = "unix:///var/run/docker.sock"
    }

    provider "helm" {
      alias = "mgmt"
      # Helm 3.x provider configuration
      burst_limit = 300
      
      kubernetes = {
        config_path    = var.global_config.kubeconfig_path
        config_context = "kind-mgmt"
      }
    }

    provider "kind" {}

    provider "kubectl" {
      alias           = "mgmt"
      config_path     = var.global_config.kubeconfig_path
      config_context  = "kind-mgmt"
      load_config_file = true
    }

    provider "kubernetes" {
      alias          = "mgmt"
      config_path    = var.global_config.kubeconfig_path
      config_context = "kind-mgmt"
    }

    provider "local" {}
    provider "null" {}
    provider "tls" {}

    provider "vault" {
      address = "https://localhost:8200"
      skip_tls_verify = true
      # Token comes from VAULT_TOKEN environment variable
    }
  EOF
}

# Common inputs that will be available to all configurations
inputs = {
  # Global configuration
  global_config = {
    default_namespace = "kube-system"
    kubeconfig_path   = pathexpand("~/.kube/config")
  }

  # Registry proxy configuration
  registry_proxy = {
    network_name = "registry-proxies"
    subnet       = "172.20.0.0/16"
    gateway      = "172.20.0.1"
  }

  # Cluster configurations
  clusters = {
    mgmt = {
      # Basic cluster configuration
      name                = "mgmt"
      worker_count        = 3
      control_plane_count = 1
      enable_ingress      = true  # Enable port mapping for ingress (80/443 -> localhost:80/443)
      pod_subnet          = "10.250.0.0/16"
      service_subnet      = "10.251.0.0/16"
      kube_proxy_mode     = "nftables"
      disable_default_cni = true
      mount_host_ca_certs = true

      # Cilium CNI configuration
      cilium = {
        version          = "1.18.2"
        cluster_id       = 250
        ipam_mode        = "kubernetes"
        enable_hubble    = true
        enable_hubble_ui = true
      }

      # Metrics server configuration
      metrics_server = {
        version  = "3.12.2"
        replicas = 1
      }

      # Vault configuration
      vault = {
        deployment_mode = "ha-raft-tls"
        version         = "0.31.0"
        enable_ui       = true
        ha_replicas     = 3

        tls = {
          enabled     = true
          secret_name = "vault-server-tls"
        }

        tls_config = {
          root_ca = {
            common_name         = "Service Nebula Root CA"
            organization        = "Service Nebula"
            organizational_unit = "Infrastructure"
            country             = "US"
            key_bits            = 4096
            validity_hours      = 87600 # 10 years
          }
          intermediate_ca = {
            common_name         = "Service Nebula Intermediate CA"
            organization        = "Service Nebula"
            organizational_unit = "Infrastructure"
            country             = "US"
            key_bits            = 4096
            validity_hours      = 43800 # 5 years
          }
          server_cert = {
            organization        = "Service Nebula"
            organizational_unit = "Infrastructure"
            key_bits            = 2048
            validity_hours      = 2160 # 90 days
          }
        }

        pki_engine = {
          enabled         = true
          mount_path      = "pki"
          max_ttl_seconds = 315360000 # 10 years

          root_ca = {
            common_name         = "Vault PKI Root CA"
            organization        = "Service Nebula"
            organizational_unit = "Platform Engineering"
            country             = "US"
            locality            = null
            province            = null
            key_type            = "rsa"
            key_bits            = 4096
            max_path_length     = 1
          }

          role_name = "cert-manager"
          allowed_domains = [
            "svc.cluster.local",
            "*.svc.cluster.local",
            "vault.svc.cluster.local",
            "cert-manager.svc.cluster.local"
          ]
          allow_subdomains            = true
          allow_bare_domains          = true
          allow_glob_domains          = true
          allow_any_name              = false
          allow_localhost             = true
          allow_ip_sans               = true
          allow_wildcard_certificates = false
          cert_max_ttl_seconds        = 7776000 # 90 days
          cert_default_ttl_seconds    = 7776000 # 90 days
          cert_key_type               = "rsa"
          cert_key_bits               = 2048

          kubernetes_auth = {
            enabled                    = true
            path                       = "kubernetes"
            kubernetes_host            = "https://kubernetes.default.svc"
            role_name                  = "cert-manager"
            service_account_names      = ["cert-manager"]
            service_account_namespaces = ["cert-manager"]
            token_ttl                  = 3600
          }

          policy_name = "cert-manager-pki"
        }

        storage = {
          size  = "10Gi"
          class = "standard"
        }
      }

      # Traefik ingress controller configuration
      traefik = {
        enabled          = true
        namespace        = "traefik"
        create_namespace = true
        release_name     = "traefik"
        chart_version    = "37.1.2"

        # Deployment configuration
        deployment = {
          enabled               = true
          kind                  = "Deployment"
          replicas              = 2
          pod_annotations       = {}
          pod_labels            = {}
          additional_containers = []
        }

        # Service configuration
        service = {
          enabled = true
          type    = "NodePort"
          annotations = {}
          labels = {}
          spec   = {}
        }

        # Ports configuration
        ports = {
          web = {
            port        = 80
            expose = {
              default = true
            }
            exposedPort = 80
            protocol    = "TCP"
          }
          websecure = {
            port        = 443
            expose = {
              default = true
            }
            exposedPort = 443
            protocol    = "TCP"
            tls = {
              enabled = true
            }
          }
          metrics = {
            port     = 9100
            expose = {
              default = false
            }
            protocol = "TCP"
          }
        }

        # Providers configuration
        providers = {
          kubernetes_crd = {
            enabled                      = true
            allow_cross_namespace        = false
            allow_external_name_services = false
            namespaces                   = []
          }
          kubernetes_ingress = {
            enabled                      = true
            allow_external_name_services = false
            namespaces                   = []
            published_service_enabled    = true
          }
        }

        # Observability
        logs = {
          general = {
            level = "INFO"
          }
          access = {
            enabled = true
          }
        }

        metrics = {
          prometheus = {
            enabled              = true
            entryPoint           = "metrics"
            addEntryPointsLabels = true
            addRoutersLabels     = true
            addServicesLabels    = true
          }
        }

        dashboard = {
          enabled  = true
          insecure = false
        }

        # Security
        security_context = {
          capabilities = {
            drop = ["ALL"]
            add  = ["NET_BIND_SERVICE"]
          }
          readOnlyRootFilesystem = true
          runAsNonRoot           = true
          runAsUser              = 65532
          runAsGroup             = 65532
        }

        pod_security_context = {
          fsGroup             = 65532
          fsGroupChangePolicy = "OnRootMismatch"
        }

        # Resources
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        # TLS configuration (integrated with cert-manager)
        tls_config = {
          enabled      = false # Will enable after testing basic deployment
          certificates = {}
          stores       = {}
        }

        # Middleware configuration
        create_default_middleware = false # Will enable after testing basic deployment
        default_middlewares       = {}

        # IngressRoutes configuration
        create_ingress_routes = true # Enable IngressRoute for Traefik dashboard
        ingress_routes = {
          # HTTP routes - Traefik Dashboard
          http = {
            dashboard = {
              entry_points = ["web"]
              routes = [
                {
                  match = "PathPrefix(`/dashboard`) || PathPrefix(`/api`)"  # Match any host
                  kind  = "Rule"
                  services = [
                    {
                      name      = "api@internal"
                      port      = 0  # Special case for api@internal (dashboard service)
                      namespace = "traefik"
                    }
                  ]
                }
              ]
            }
          }
          https = {}
          tcp   = {}
          udp   = {}
        }
      }
    }
  }

  # cert-manager configuration
  cert_manager = {
    namespace        = "cert-manager"
    version          = "v1.18.2"
    create_namespace = true
    install_crds     = true
  }
}

# Terragrunt hooks for better automation
terraform {
  # Before hook to ensure providers are downloaded
  before_hook "before_init" {
    commands     = ["init"]
    execute      = ["echo", "🔧 Initializing OpenTofu with Terragrunt..."]
    run_on_error = false
  }

  # After hook for successful apply
  after_hook "after_apply" {
    commands     = ["apply"]
    execute      = ["echo", "✅ Infrastructure deployment complete!"]
    run_on_error = false
  }

  # After hook for successful destroy
  after_hook "after_destroy" {
    commands     = ["destroy"]
    execute      = ["echo", "✅ Infrastructure destruction complete!"]
    run_on_error = false
  }

  # Extra arguments for all commands
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }

  # Retry configuration for transient errors
  extra_arguments "retry_config" {
    commands = [
      "init",
      "apply",
      "destroy",
      "plan",
    ]
    
    env_vars = {
      TF_PLUGIN_CACHE_DIR = "${get_env("HOME", "")}/.terraform.d/plugin-cache"
    }
  }
}

# Configure download directory for Terraform working files
download_dir = "${get_env("HOME", "")}/.terragrunt-cache"

# Configure retry logic for transient errors
retryable_errors = [
  "(?s).*failed to download.*",
  "(?s).*connection reset by peer.*",
  "(?s).*TLS handshake timeout.*",
  "(?s).*temporary failure in name resolution.*",
  "(?s).*i/o timeout.*",
]

retry_max_attempts       = 3
retry_sleep_interval_sec = 5
