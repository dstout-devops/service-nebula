# Vault Module Main Configuration
# Implements HashiCorp's recommended deployment patterns

# Create namespace for Vault
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.namespace
    
    labels = {
      name = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Local values for configuration logic
locals {
  is_ha           = contains(["ha-raft", "ha-raft-tls"], var.deployment_mode)
  is_tls_enabled  = contains(["standalone-tls", "ha-raft-tls"], var.deployment_mode) || var.enable_tls
  
  # Base Helm values that apply to all modes
  base_values = {
    global = {
      enabled = true
      tlsDisable = !local.is_tls_enabled
    }
    
    ui = {
      enabled = var.enable_ui
      serviceType = var.service_type
    }
    
    injector = {
      enabled = var.enable_injector
    }
  }
  
  # Standalone configuration (Phase 2: Integrated Storage)
  standalone_values = {
    server = {
      resources = var.server_resources
      
      dataStorage = {
        enabled = true
        size = var.storage_size
        storageClass = var.storage_class
      }
      
      standalone = {
        enabled = true
        config = <<-EOT
          ui = true
          
          listener "tcp" {
            tls_disable = 1
            address = "[::]:8200"
            cluster_address = "[::]:8201"
          }
          
          storage "file" {
            path = "/vault/data"
          }
        EOT
      }
      
      ha = {
        enabled = false
      }
    }
  }
  
  # Standalone with TLS configuration (Phase 3: Add TLS)
  standalone_tls_values = {
    server = {
      resources = var.server_resources
      
      dataStorage = {
        enabled = true
        size = var.storage_size
        storageClass = var.storage_class
      }
      
      volumes = [
        {
          name = "vault-server-tls"
          secret = {
            secretName = var.tls_secret_name
          }
        }
      ]
      
      volumeMounts = [
        {
          name = "vault-server-tls"
          mountPath = "/vault/tls"
          readOnly = true
        }
      ]
      
      standalone = {
        enabled = true
        config = <<-EOT
          ui = true
          
          listener "tcp" {
            tls_disable = 0
            address = "[::]:8200"
            cluster_address = "[::]:8201"
            tls_cert_file = "/vault/tls/tls.crt"
            tls_key_file = "/vault/tls/tls.key"
            tls_client_ca_file = "/vault/tls/ca.crt"
          }
          
          storage "file" {
            path = "/vault/data"
          }
        EOT
      }
      
      ha = {
        enabled = false
      }
    }
  }
  
  # HA with Raft storage (Phase 4: Production HA)
  ha_raft_values = {
    server = {
      resources = var.server_resources
      
      dataStorage = {
        enabled = true
        size = var.storage_size
        storageClass = var.storage_class
      }
      
      ha = {
        enabled = true
        replicas = var.ha_replicas
        
        raft = {
          enabled = true
          setNodeId = true
          
          config = <<-EOT
            ui = true
            
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            
            storage "raft" {
              path = "/vault/data"
              
              retry_join {
                leader_api_addr = "http://vault-0.vault-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://vault-1.vault-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://vault-2.vault-internal:8200"
              }
            }
            
            service_registration "kubernetes" {}
          EOT
        }
      }
      
      standalone = {
        enabled = false
      }
    }
  }
  
  # HA with Raft and TLS (Phase 4: Production HA + TLS)
  ha_raft_tls_values = {
    server = {
      resources = var.server_resources
      
      dataStorage = {
        enabled = true
        size = var.storage_size
        storageClass = var.storage_class
      }
      
      volumes = [
        {
          name = "vault-server-tls"
          secret = {
            secretName = var.tls_secret_name
          }
        }
      ]
      
      volumeMounts = [
        {
          name = "vault-server-tls"
          mountPath = "/vault/tls"
          readOnly = true
        }
      ]
      
      ha = {
        enabled = true
        replicas = var.ha_replicas
        
        raft = {
          enabled = true
          setNodeId = true
          
          config = <<-EOT
            ui = true
            
            listener "tcp" {
              tls_disable = 0
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_cert_file = "/vault/tls/tls.crt"
              tls_key_file = "/vault/tls/tls.key"
              tls_client_ca_file = "/vault/tls/ca.crt"
            }
            
            storage "raft" {
              path = "/vault/data"
              
              retry_join {
                leader_api_addr = "https://vault-0.vault-internal:8200"
                leader_ca_cert_file = "/vault/tls/ca.crt"
                leader_client_cert_file = "/vault/tls/tls.crt"
                leader_client_key_file = "/vault/tls/tls.key"
              }
              retry_join {
                leader_api_addr = "https://vault-1.vault-internal:8200"
                leader_ca_cert_file = "/vault/tls/ca.crt"
                leader_client_cert_file = "/vault/tls/tls.crt"
                leader_client_key_file = "/vault/tls/tls.key"
              }
              retry_join {
                leader_api_addr = "https://vault-2.vault-internal:8200"
                leader_ca_cert_file = "/vault/tls/ca.crt"
                leader_client_cert_file = "/vault/tls/tls.crt"
                leader_client_key_file = "/vault/tls/tls.key"
              }
            }
            
            service_registration "kubernetes" {}
          EOT
        }
      }
      
      standalone = {
        enabled = false
      }
    }
  }
  
  # Select configuration based on deployment mode
  server_values = (
    var.deployment_mode == "standalone" ? local.standalone_values :
    var.deployment_mode == "standalone-tls" ? local.standalone_tls_values :
    var.deployment_mode == "ha-raft" ? local.ha_raft_values :
    local.ha_raft_tls_values
  )
  
  # Merge base and mode-specific values
  helm_values = merge(local.base_values, local.server_values)
}

# Deploy Vault using Helm
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_version
  namespace  = kubernetes_namespace.vault.metadata[0].name
  
  values = [
    yamlencode(local.helm_values)
  ]
  
  wait          = true
  wait_for_jobs = true
  timeout       = 600
  
  depends_on = [kubernetes_namespace.vault]
}
