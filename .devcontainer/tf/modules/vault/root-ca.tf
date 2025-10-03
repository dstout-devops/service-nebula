# Root CA Infrastructure for Vault TLS
# Uses step-ca to generate certificate chain for Vault server TLS
# Note: This is separate from Vault's PKI secrets engine (used for issuing application certificates)
#
# Certificate Hierarchy:
#   Root CA (10 years) → Intermediate CA (5 years) → Vault Server Cert (90 days)

locals {
  pki_dir = "/tmp/vault-pki-${var.cluster_name}-${var.namespace}"
}

# Generate Root CA
resource "null_resource" "generate_root_ca" {
  count = local.is_tls_enabled ? 1 : 0
  
  triggers = {
    cluster_name = var.cluster_name
    namespace    = var.namespace
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CERT_DIR="${local.pki_dir}"
      mkdir -p "$CERT_DIR"
      cd "$CERT_DIR"
      
      echo "📜 Generating Root CA for Service Nebula..."
      step certificate create "Service Nebula Root CA" \
        root-ca.crt root-ca.key \
        --profile root-ca \
        --no-password \
        --insecure \
        --not-after=87600h \
        --force
      
      echo "✅ Root CA generated successfully"
      step certificate inspect root-ca.crt --short
    EOT
  }
}

# Generate Intermediate CA
resource "null_resource" "generate_intermediate_ca" {
  count      = local.is_tls_enabled ? 1 : 0
  depends_on = [null_resource.generate_root_ca]
  
  triggers = {
    cluster_name = var.cluster_name
    namespace    = var.namespace
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CERT_DIR="${local.pki_dir}"
      cd "$CERT_DIR"
      
      echo "🔐 Generating Intermediate CA for Vault..."
      step certificate create "Service Nebula Vault Intermediate CA" \
        vault-intermediate.crt vault-intermediate.key \
        --profile intermediate-ca \
        --ca root-ca.crt \
        --ca-key root-ca.key \
        --no-password \
        --insecure \
        --not-after=43800h \
        --force
      
      cat vault-intermediate.crt root-ca.crt > ca-bundle.crt
      
      echo "✅ Intermediate CA generated successfully"
      step certificate inspect vault-intermediate.crt --short
    EOT
  }
}

# Generate Vault Server Certificate
resource "null_resource" "generate_vault_server_cert" {
  count      = local.is_tls_enabled ? 1 : 0
  depends_on = [null_resource.generate_intermediate_ca]
  
  triggers = {
    cluster_name = var.cluster_name
    namespace    = var.namespace
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CERT_DIR="${local.pki_dir}"
      cd "$CERT_DIR"
      
      echo "🔒 Generating Vault server certificate..."
      step certificate create "vault.${var.namespace}.svc.cluster.local" \
        tls.crt tls.key \
        --profile leaf \
        --ca vault-intermediate.crt \
        --ca-key vault-intermediate.key \
        --san vault \
        --san vault.${var.namespace} \
        --san vault.${var.namespace}.svc \
        --san vault.${var.namespace}.svc.cluster.local \
        --san vault-0.vault-internal \
        --san vault-1.vault-internal \
        --san vault-2.vault-internal \
        --san vault-0.vault-internal.${var.namespace}.svc.cluster.local \
        --san vault-1.vault-internal.${var.namespace}.svc.cluster.local \
        --san vault-2.vault-internal.${var.namespace}.svc.cluster.local \
        --san '*.vault-internal' \
        --san '*.vault-internal.${var.namespace}.svc.cluster.local' \
        --san 127.0.0.1 \
        --no-password \
        --insecure \
        --not-after=2160h \
        --force
      
      echo "✅ Vault server certificate generated successfully"
      step certificate inspect tls.crt --short
      
      echo ""
      echo "📋 Certificate chain:"
      echo "  Root CA: $(step certificate inspect root-ca.crt --format json | jq -r .subject.common_name)"
      echo "  Intermediate CA: $(step certificate inspect vault-intermediate.crt --format json | jq -r .subject.common_name)"
      echo "  Server Cert: $(step certificate inspect tls.crt --format json | jq -r .subject.common_name)"
      echo ""
      echo "🔍 Verifying certificate chain..."
      step certificate verify tls.crt --roots root-ca.crt --intermediates vault-intermediate.crt
    EOT
  }
}

# Create Kubernetes secret with PKI certificates
resource "kubernetes_secret" "vault_pki" {
  count      = local.is_tls_enabled ? 1 : 0
  depends_on = [null_resource.generate_vault_server_cert]
  
  metadata {
    name      = var.tls_secret_name
    namespace = var.namespace
    
    labels = {
      "app.kubernetes.io/name"       = "vault"
      "app.kubernetes.io/component"  = "pki"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  data = {
    "tls.crt" = "# Placeholder"
    "tls.key" = "# Placeholder"
    "ca.crt"  = "# Placeholder"
  }
  
  type = "Opaque"
  
  lifecycle {
    ignore_changes = [data]
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      CERT_DIR="${local.pki_dir}"
      
      if [ -d "$CERT_DIR" ] && [ -f "$CERT_DIR/tls.crt" ]; then
        echo "📦 Creating Kubernetes secret with PKI certificates..."
        kubectl create secret generic ${var.tls_secret_name} \
          --from-file=tls.crt="$CERT_DIR/tls.crt" \
          --from-file=tls.key="$CERT_DIR/tls.key" \
          --from-file=ca.crt="$CERT_DIR/ca-bundle.crt" \
          -n ${var.namespace} \
          --dry-run=client -o yaml | kubectl apply -f -
        echo "✅ PKI secret created successfully"
      else
        echo "⚠️  Certificate directory not found: $CERT_DIR"
        exit 1
      fi
    EOT
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Clean up PKI certificates from /tmp
      # Pattern: /tmp/vault-pki-*
      find /tmp -maxdepth 1 -type d -name 'vault-pki-*' -exec rm -rf {} + 2>/dev/null || true
      echo "✅ PKI cleanup complete"
    EOT
  }
}
