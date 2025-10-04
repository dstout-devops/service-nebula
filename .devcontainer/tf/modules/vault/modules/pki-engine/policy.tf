# Vault Policy for cert-manager PKI Access
# Defines what operations cert-manager can perform on the PKI secrets engine

resource "vault_policy" "cert_manager" {
  count = var.enabled ? 1 : 0

  name = var.policy_name

  policy = <<-EOT
    # Allow cert-manager to sign certificates using the configured role
    path "${var.mount_path}/sign/${var.role_name}" {
      capabilities = ["create", "update"]
    }

    # Allow cert-manager to issue certificates using the configured role
    path "${var.mount_path}/issue/${var.role_name}" {
      capabilities = ["create", "update"]
    }

    # Allow reading the CA certificate
    path "${var.mount_path}/cert/ca" {
      capabilities = ["read"]
    }

    # Allow reading the CA chain
    path "${var.mount_path}/ca_chain" {
      capabilities = ["read"]
    }

    # Allow reading the CRL
    path "${var.mount_path}/crl" {
      capabilities = ["read"]
    }
  EOT
}
