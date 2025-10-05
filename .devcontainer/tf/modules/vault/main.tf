# Vault Module Main Configuration
# Implements HashiCorp's recommended deployment patterns

# Create namespace for Vault
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.namespace

    labels = {
      name                                 = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Local values for configuration logic
locals {
  is_ha          = contains(["ha-raft", "ha-raft-tls"], var.deployment_mode)
  is_tls_enabled = contains(["standalone-tls", "ha-raft-tls"], var.deployment_mode) || var.tls.enabled

  # Computed service addresses
  internal_service_fqdn = "${var.internal_service_name}.${var.namespace}.svc.cluster.local"
  vault_protocol        = local.is_tls_enabled ? "https" : "http"
  vault_fqdn            = "${var.service_name}.${var.namespace}.svc.cluster.local"

  # Retry join addresses for HA mode
  retry_join_addrs = local.is_ha ? [
    for i in range(var.ha_replicas) : "${local.vault_protocol}://vault-${i}.${var.internal_service_name}:8200"
  ] : []

  # Common TLS volume and mount configuration (reused across deployment modes)
  tls_volumes = local.is_tls_enabled ? [
    {
      name = "userconfig-vault-server-tls"
      secret = {
        defaultMode = 420
        secretName  = var.tls.secret_name
      }
    }
  ] : []

  tls_volume_mounts = local.is_tls_enabled ? [
    {
      name      = "userconfig-vault-server-tls"
      mountPath = var.paths.userconfig_path
      readOnly  = true
    }
  ] : []

  tls_env_vars = local.is_tls_enabled ? {
    VAULT_CACERT = "${var.paths.userconfig_path}/vault.ca"
  } : {}

  # Common listener configuration (used in server config across all modes)
  listener_tls = <<-EOT
    listener "tcp" {
      tls_disable = 0
      address = "${var.listener.api_addr}"
      cluster_address = "${var.listener.cluster_addr}"
      tls_cert_file = "${var.paths.userconfig_path}/vault.crt"
      tls_key_file = "${var.paths.userconfig_path}/vault.key"
      tls_client_ca_file = "${var.paths.userconfig_path}/vault.ca"
    }
  EOT

  listener_no_tls = <<-EOT
    listener "tcp" {
      tls_disable = 1
      address = "${var.listener.api_addr}"
      cluster_address = "${var.listener.cluster_addr}"
    }
  EOT

  listener_config = local.is_tls_enabled ? local.listener_tls : local.listener_no_tls

  # Base Helm values that apply to all modes
  base_values = {
    global = {
      enabled    = true
      tlsDisable = !local.is_tls_enabled
    }

    ui = {
      enabled     = var.enable_ui
      serviceType = var.service_type
    }

    injector = {
      enabled  = var.injector.enabled
      replicas = var.injector.replicas
      leaderElector = {
        enabled = var.injector.leader_elector
      }
      certs = var.injector.use_cert_manager ? {
        secretName = var.injector.tls_secret_name
      } : {}
      webhook = var.injector.use_cert_manager ? {
        annotations = var.injector.webhook_annotations
      } : {}
    }
  }

  # Common server configuration (used by all deployment modes)
  common_server = {
    resources = var.server_resources

    dataStorage = {
      enabled      = true
      size         = var.storage.size
      storageClass = var.storage.class
    }

    extraEnvironmentVars = local.tls_env_vars
    volumes              = local.tls_volumes
    volumeMounts         = local.tls_volume_mounts
  }

  # Storage configurations for different modes
  standalone_storage = <<-EOT
    storage "file" {
      path = "${var.paths.data_path}"
    }
  EOT

  raft_storage_no_tls = <<-EOT
    storage "raft" {
      path = "${var.paths.data_path}"
      %{for addr in local.retry_join_addrs~}
      retry_join {
        leader_api_addr = "${addr}"
      }
      %{endfor~}
    }
    
    service_registration "kubernetes" {}
  EOT

  raft_storage_tls = <<-EOT
    storage "raft" {
      path = "${var.paths.data_path}"
      %{for addr in local.retry_join_addrs~}
      retry_join {
        leader_api_addr = "${addr}"
        leader_tls_servername = "${local.vault_fqdn}"
        leader_ca_cert_file = "${var.paths.userconfig_path}/vault.ca"
        leader_client_cert_file = "${var.paths.userconfig_path}/vault.crt"
        leader_client_key_file = "${var.paths.userconfig_path}/vault.key"
      }
      %{endfor~}
    }
    
    service_registration "kubernetes" {}
  EOT

  # Deployment mode configurations
  standalone_values = {
    server = merge(local.common_server, {
      standalone = {
        enabled = true
        config  = <<-EOT
          ui = ${var.enable_ui}
          ${local.listener_config}
          ${local.standalone_storage}
        EOT
      }
      ha = {
        enabled  = false
        replicas = 1
        raft = {
          enabled   = false
          setNodeId = false
          config    = ""
        }
      }
    })
  }

  standalone_tls_values = {
    server = merge(local.common_server, {
      standalone = {
        enabled = true
        config  = <<-EOT
          ui = ${var.enable_ui}
          ${local.listener_config}
          ${local.standalone_storage}
        EOT
      }
      ha = {
        enabled  = false
        replicas = 1
        raft = {
          enabled   = false
          setNodeId = false
          config    = ""
        }
      }
    })
  }

  ha_raft_values = {
    server = merge(local.common_server, {
      ha = {
        enabled  = true
        replicas = var.ha_replicas
        raft = {
          enabled   = true
          setNodeId = true
          config    = <<-EOT
            ui = ${var.enable_ui}
            ${local.listener_config}
            ${local.raft_storage_no_tls}
          EOT
        }
      }
      standalone = {
        enabled = false
      }
    })
  }

  ha_raft_tls_values = {
    server = merge(local.common_server, {
      ha = {
        enabled  = true
        replicas = var.ha_replicas
        raft = {
          enabled   = true
          setNodeId = true
          config    = <<-EOT
            ui = ${var.enable_ui}
            ${local.listener_config}
            ${local.raft_storage_tls}
          EOT
        }
      }
      standalone = {
        enabled = false
      }
    })
  }

  # Map deployment mode to configuration
  deployment_configs = {
    "standalone"     = local.standalone_values
    "standalone-tls" = local.standalone_tls_values
    "ha-raft"        = local.ha_raft_values
    "ha-raft-tls"    = local.ha_raft_tls_values
  }

}

# Deploy Vault using Helm
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  values = [
    yamlencode(merge(
      local.base_values,
      local.deployment_configs[var.deployment_mode]
    ))
  ]

  # Don't wait for pods to be ready - they need init/unseal first
  wait          = false
  wait_for_jobs = false
  timeout       = 600

  depends_on = [kubernetes_namespace.vault]
}

# ============================================================================
# Init Submodule
# Handles Vault initialization and unsealing
# ============================================================================

module "init" {
  source = "./modules/init"

  namespace               = kubernetes_namespace.vault.metadata[0].name
  deployment_mode         = var.deployment_mode
  is_ha                   = local.is_ha
  is_tls_enabled          = local.is_tls_enabled
  service_name            = var.service_name
  internal_service_name   = var.internal_service_name
  vault_protocol          = local.vault_protocol
  userconfig_path         = var.paths.userconfig_path
  unseal_keys_secret_name = var.unseal_keys_secret_name

  depends_on = [helm_release.vault]
}

# ============================================================================
# TLS Submodule
# Manages TLS/CA infrastructure for Vault server communications
# ============================================================================

module "tls" {
  source = "./modules/tls"

  enabled   = local.is_tls_enabled
  namespace = kubernetes_namespace.vault.metadata[0].name

  k8s_secret_name = var.tls.secret_name

  # Root CA Configuration
  root_ca = {
    common_name         = var.tls_config.root_ca.common_name
    organization        = var.tls_config.root_ca.organization
    organizational_unit = var.tls_config.root_ca.organizational_unit
    country             = var.tls_config.root_ca.country
    key_algorithm       = "RSA"
    key_bits            = var.tls_config.root_ca.key_bits
    validity_hours      = var.tls_config.root_ca.validity_hours
    early_renewal_hours = var.tls_config.root_ca.early_renewal_hours
  }

  # Intermediate CA Configuration
  intermediate_ca = {
    common_name         = var.tls_config.intermediate_ca.common_name
    organization        = var.tls_config.intermediate_ca.organization
    organizational_unit = var.tls_config.intermediate_ca.organizational_unit
    country             = var.tls_config.intermediate_ca.country
    key_algorithm       = "RSA"
    key_bits            = var.tls_config.intermediate_ca.key_bits
    validity_hours      = var.tls_config.intermediate_ca.validity_hours
    early_renewal_hours = var.tls_config.intermediate_ca.early_renewal_hours
  }

  # Server Certificate Configuration
  server_cert = {
    common_name         = local.vault_fqdn
    organization        = var.tls_config.server_cert.organization
    organizational_unit = var.tls_config.server_cert.organizational_unit
    dns_names = [
      var.service_name,
      "${var.service_name}.${var.namespace}",
      "${var.service_name}.${var.namespace}.svc",
      "${var.service_name}.${var.namespace}.svc.cluster.local",
      "*.${var.internal_service_name}",
      "*.${var.internal_service_name}.${var.namespace}",
      "*.${var.internal_service_name}.${var.namespace}.svc",
      "*.${var.internal_service_name}.${var.namespace}.svc.cluster.local",
      var.internal_service_name,
      "${var.internal_service_name}.${var.namespace}",
      "${var.internal_service_name}.${var.namespace}.svc",
      "${var.internal_service_name}.${var.namespace}.svc.cluster.local",
      "localhost"
    ]
    ip_addresses        = ["127.0.0.1"]
    key_algorithm       = "RSA"
    key_bits            = var.tls_config.server_cert.key_bits
    validity_hours      = var.tls_config.server_cert.validity_hours
    early_renewal_hours = var.tls_config.server_cert.early_renewal_hours
  }
}

# ============================================================================
# PKI Engine Submodule
# Manages PKI secrets engine for cert-manager integration
# ============================================================================

module "pki_engine" {
  source = "./modules/pki-engine"

  enabled         = var.pki_engine.enabled
  mount_path      = var.pki_engine.mount_path
  vault_addr      = "${local.vault_protocol}://${local.vault_fqdn}:8200"
  max_ttl_seconds = var.pki_engine.max_ttl_seconds

  # Root CA Configuration for PKI Secrets Engine
  root_ca = var.pki_engine.root_ca

  # PKI Role Configuration
  role_name                   = var.pki_engine.role_name
  allowed_domains             = var.pki_engine.allowed_domains
  allow_subdomains            = var.pki_engine.allow_subdomains
  allow_bare_domains          = var.pki_engine.allow_bare_domains
  allow_glob_domains          = var.pki_engine.allow_glob_domains
  allow_any_name              = var.pki_engine.allow_any_name
  allow_localhost             = var.pki_engine.allow_localhost
  allow_ip_sans               = var.pki_engine.allow_ip_sans
  allow_wildcard_certificates = var.pki_engine.allow_wildcard_certificates
  cert_max_ttl_seconds        = var.pki_engine.cert_max_ttl_seconds
  cert_default_ttl_seconds    = var.pki_engine.cert_default_ttl_seconds
  cert_key_type               = var.pki_engine.cert_key_type
  cert_key_bits               = var.pki_engine.cert_key_bits

  # Kubernetes Authentication Configuration
  kubernetes_auth = {
    enabled                    = var.pki_engine.kubernetes_auth.enabled
    path                       = var.pki_engine.kubernetes_auth.path
    kubernetes_host            = var.pki_engine.kubernetes_auth.kubernetes_host
    kubernetes_ca_cert         = try(file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"), "")
    role_name                  = var.pki_engine.kubernetes_auth.role_name
    service_account_names      = var.pki_engine.kubernetes_auth.service_account_names
    service_account_namespaces = var.pki_engine.kubernetes_auth.service_account_namespaces
    token_ttl                  = var.pki_engine.kubernetes_auth.token_ttl
  }

  # Policy Configuration
  policy_name = var.pki_engine.policy_name

  # Wait for Vault to be initialized and unsealed
  depends_on = [module.init]
}
