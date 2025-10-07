// Vault initialization and unseal implemented as in-cluster Kubernetes Job
// This replaces local-exec provisioners with a namespaced ServiceAccount + Role
// and a single Job which runs the init/unseal logic inside the cluster.
// The script is stored in a ConfigMap for cleanliness and mounted as a volume.

// Service account used by the Job
resource "kubernetes_service_account" "vault_init" {
  metadata {
    name      = "vault-init-sa"
    namespace = var.namespace
    labels = {
      app = "vault-init"
    }
  }
}

// Minimal Role granting access required by the init job: pods exec, pods get/list, secrets create/patch
resource "kubernetes_role" "vault_init" {
  metadata {
    name      = "vault-init-role"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec"]
    verbs      = ["get", "list", "create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "patch", "update"]
  }
}

resource "kubernetes_role_binding" "vault_init" {
  metadata {
    name      = "vault-init-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_init.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_init.metadata[0].name
    namespace = var.namespace
  }
}

// ConfigMap containing the vault initialization script
resource "kubernetes_config_map" "vault_init_script" {
  metadata {
    name      = "vault-init-script"
    namespace = var.namespace
    labels = {
      app = "vault-init"
    }
  }

  data = {
    "init.sh" = templatefile("${path.module}/scripts/vault-init.sh", {
      namespace              = var.namespace
      is_ha                  = var.is_ha
      is_tls_enabled         = var.is_tls_enabled
      service_name           = var.service_name
      internal_service_name  = var.internal_service_name
      vault_protocol         = var.vault_protocol
      userconfig_path        = var.userconfig_path
      unseal_keys_secret_name = var.unseal_keys_secret_name
    })
  }
}

// One idempotent Job that performs wait -> init -> unseal -> HA join (when is_ha)
resource "kubernetes_job" "vault_init_job" {
  metadata {
    name      = "vault-init-job"
    namespace = var.namespace
    labels = {
      app = "vault-init"
    }
  }

  spec {
    backoff_limit              = 0
    ttl_seconds_after_finished = 300
    active_deadline_seconds    = 1200  # 20 minutes for job to complete

    template {
      metadata {
        labels = {
          app = "vault-init"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.vault_init.metadata[0].name
        restart_policy       = "Never"

        volume {
          name = "init-script"
          config_map {
            name         = kubernetes_config_map.vault_init_script.metadata[0].name
            default_mode = "0755"
          }
        }

        container {
          name              = "vault-init"
          image             = "alpine/k8s:1.34.1"
          image_pull_policy = "IfNotPresent"
          command           = ["/scripts/init.sh"]

          volume_mount {
            name       = "init-script"
            mount_path = "/scripts"
            read_only  = true
          }
        }
      }
    }
  }

  # Terraform waits up to 25 minutes for the job to complete
  timeouts {
    create = "5m"
    update = "5m"
  }

  wait_for_completion = true

  depends_on = [kubernetes_config_map.vault_init_script]
}
