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

variable "registry_proxy" {
  description = "Container registry proxy configuration"
  type = object({
    network_name = string
    subnet       = string
    gateway      = string
  })

  default = {
    network_name = "registry-proxies"
    subnet       = "172.20.0.0/16"
    gateway      = "172.20.0.1"
  }
}

variable "clusters" {
  description = "Cluster configurations"
  type = map(object({
    # Kind cluster configuration
    worker_count        = number
    control_plane_count = number
    enable_ingress      = bool
    pod_subnet          = string
    service_subnet      = string
    kube_proxy_mode     = string
    disable_default_cni = bool
    mount_host_ca_certs = bool

    # Cilium configuration
    cilium = object({
      version          = string
      cluster_id       = number
      ipam_mode        = string
      enable_hubble    = bool
      enable_hubble_ui = bool
    })

    # Metrics-server configuration
    metrics_server = object({
      version  = string
      replicas = number
    })

    # Vault configuration
    vault = object({
      deployment_mode = string
      version         = string
      enable_ui       = bool
      ha_replicas     = number

      # TLS Configuration
      tls = object({
        enabled     = bool
        secret_name = string
      })

      # TLS/CA Certificate Configuration (for Vault server TLS)
      tls_config = object({
        root_ca = object({
          common_name         = string
          organization        = string
          organizational_unit = optional(string)
          country             = optional(string)
          key_bits            = optional(number)
          validity_hours      = optional(number)
        })
        intermediate_ca = object({
          common_name         = string
          organization        = string
          organizational_unit = optional(string)
          country             = optional(string)
          key_bits            = optional(number)
          validity_hours      = optional(number)
        })
        server_cert = object({
          organization        = string
          organizational_unit = optional(string)
          key_bits            = optional(number)
          validity_hours      = optional(number)
        })
      })

      # PKI Secrets Engine Configuration (for cert-manager)
      pki_engine = object({
        enabled         = bool
        mount_path      = string
        max_ttl_seconds = number

        root_ca = object({
          common_name         = string
          organization        = string
          organizational_unit = optional(string)
          country             = optional(string)
          locality            = optional(string)
          province            = optional(string)
          key_type            = optional(string)
          key_bits            = optional(number)
          max_path_length     = optional(number)
        })

        role_name                   = string
        allowed_domains             = list(string)
        allow_subdomains            = bool
        allow_bare_domains          = bool
        allow_glob_domains          = bool
        allow_any_name              = bool
        allow_localhost             = bool
        allow_ip_sans               = bool
        allow_wildcard_certificates = bool
        cert_max_ttl_seconds        = number
        cert_default_ttl_seconds    = number
        cert_key_type               = string
        cert_key_bits               = number

        kubernetes_auth = object({
          enabled                    = bool
          path                       = string
          kubernetes_host            = string
          role_name                  = string
          service_account_names      = list(string)
          service_account_namespaces = list(string)
          token_ttl                  = number
        })

        policy_name = string
      })

      # Storage Configuration
      storage = object({
        size  = string
        class = string
      })
    })

    # Traefik Ingress Controller configuration
    traefik = optional(object({
      enabled          = bool
      namespace        = string
      create_namespace = bool
      release_name     = string
      chart_version    = string
      deployment       = any
      service          = any
      ports            = any
      providers        = any
      logs             = any
      metrics          = any
      dashboard        = any
      security_context = any
      pod_security_context = any
      resources        = any
      tls_config       = any
      create_default_middleware = bool
      default_middlewares = any
      create_ingress_routes = bool
      ingress_routes   = any
    }))
  }))

  default = {
    mgmt = {
      worker_count        = 3
      control_plane_count = 1
      enable_ingress      = false
      pod_subnet          = "10.250.0.0/16"
      service_subnet      = "10.251.0.0/16"
      kube_proxy_mode     = "nftables"
      disable_default_cni = true
      mount_host_ca_certs = true

      cilium = {
        version          = "1.18.2"
        cluster_id       = 250
        ipam_mode        = "kubernetes"
        enable_hubble    = true
        enable_hubble_ui = true
      }

      metrics_server = {
        version  = "3.13.0"
        replicas = 1
      }

      vault = {
        deployment_mode = "ha-raft-tls" # Options: standalone, standalone-tls, ha-raft, ha-raft-tls
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
          allow_any_name              = false   # Restrict to allowed_domains for security
          allow_localhost             = true    # Allow localhost for development
          allow_ip_sans               = true    # Allow IP SANs for pod IPs
          allow_wildcard_certificates = false   # Disable wildcards for better security
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
            token_ttl                  = 3600 # 1 hour
          }

          policy_name = "cert-manager-pki"
        }

        storage = {
          size  = "10Gi"
          class = "standard"
        }
      }
    }
  }
}
