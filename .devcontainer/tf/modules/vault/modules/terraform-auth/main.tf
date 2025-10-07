# Terraform Authentication Configuration
# Creates Kubernetes auth backend and role for Terraform to manage Vault resources

# ============================================================================
# Kubernetes Auth Backend (Shared by terraform and cert-manager)
# ============================================================================

resource "vault_auth_backend" "kubernetes" {
  count = var.enabled && var.create_auth_backend ? 1 : 0

  type = "kubernetes"
  path = var.kubernetes_auth_path

  description = "Kubernetes authentication backend"
}

# ============================================================================
# Kubernetes Auth Backend Configuration
# ============================================================================

resource "vault_kubernetes_auth_backend_config" "config" {
  count = var.enabled && var.create_auth_backend ? 1 : 0

  backend            = vault_auth_backend.kubernetes[0].path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert

  # Use default service account token for auth
  disable_local_ca_jwt = false
}

# ============================================================================
# Kubernetes ServiceAccount for Terraform
# ============================================================================

resource "kubernetes_service_account" "terraform" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = var.namespace
  }
}

# ============================================================================
# Kubernetes Auth Backend Role for Terraform
# ============================================================================

resource "vault_kubernetes_auth_backend_role" "terraform" {
  count = var.enabled ? 1 : 0

  backend                          = var.create_auth_backend ? vault_auth_backend.kubernetes[0].path : var.kubernetes_auth_path
  role_name                        = var.role_name
  bound_service_account_names      = [var.service_account_name]
  bound_service_account_namespaces = [var.namespace]
  token_ttl                        = var.token_ttl
  token_policies                   = concat([vault_policy.terraform[0].name], var.token_policies)

  # Allow token renewal
  token_period = var.token_ttl
}

# ============================================================================
# Policy for Terraform
# ============================================================================

resource "vault_policy" "terraform" {
  count = var.enabled ? 1 : 0

  name = var.policy_name

  policy = <<-EOT
    # Allow full access to PKI secrets engine
    path "${var.pki_mount_path}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Allow configuring Kubernetes auth
    path "auth/kubernetes/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Allow managing policies
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Allow managing auth methods
    path "sys/auth/*" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    # Allow managing mounts
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "sudo"]
    }

    # Allow reading system health and capabilities
    path "sys/health" {
      capabilities = ["read"]
    }

    path "sys/capabilities-self" {
      capabilities = ["read"]
    }
  EOT
}
