# Vault Initialization and Unsealing
# Automates the init and unseal process for development

# Wait for Vault pods to be ready
resource "null_resource" "wait_for_vault" {
  depends_on = [helm_release.vault]
  
  triggers = {
    deployment_mode = var.deployment_mode
    timestamp       = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "⏳ Waiting for Vault pods to be running (not ready - that requires unsealing)..."
      
      # Wait for pods to exist and be in Running state
      # Note: Vault pods won't be "Ready" until initialized and unsealed
      RETRY=0
      MAX_RETRIES=60
      while [ $RETRY -lt $MAX_RETRIES ]; do
        POD_COUNT=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$POD_COUNT" -gt 0 ]; then
          echo "✅ Vault pod(s) are running (found $POD_COUNT)"
          break
        fi
        echo "  Waiting for Vault pods to start... ($RETRY/$MAX_RETRIES)"
        sleep 5
        RETRY=$((RETRY + 1))
      done
      
      if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "❌ Timeout waiting for Vault pods"
        kubectl get pods -n ${var.namespace}
        exit 1
      fi
    EOT
  }
}

# Initialize Vault
resource "null_resource" "vault_init" {
  depends_on = [null_resource.wait_for_vault]
  
  triggers = {
    deployment_mode = var.deployment_mode
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "🔐 Initializing Vault..."
      
      # Set Vault address based on TLS
      if [ "${local.is_tls_enabled}" = "true" ]; then
        export VAULT_ADDR='https://vault.${var.namespace}.svc.cluster.local:8200'
        export VAULT_SKIP_VERIFY=1
      else
        export VAULT_ADDR='http://vault.${var.namespace}.svc.cluster.local:8200'
      fi
      
      # Check if already initialized
      POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
      
      if kubectl exec -n ${var.namespace} $POD_NAME -- vault status 2>&1 | grep -q "Sealed.*true\|Initialized.*false"; then
        echo "Initializing Vault..."
        
        # Initialize with 1 key share and threshold for dev (adjust for production!)
        kubectl exec -n ${var.namespace} $POD_NAME -- vault operator init \
          -key-shares=1 \
          -key-threshold=1 \
          -format=json > /tmp/vault-init-keys.json
        
        echo "✅ Vault initialized successfully"
        echo "🔑 Init keys saved to /tmp/vault-init-keys.json"
        
        # Save unseal key and root token for dev purposes
        UNSEAL_KEY=$(cat /tmp/vault-init-keys.json | jq -r '.unseal_keys_b64[0]')
        ROOT_TOKEN=$(cat /tmp/vault-init-keys.json | jq -r '.root_token')
        
        echo "VAULT_UNSEAL_KEY=$UNSEAL_KEY" > /tmp/vault-credentials
        echo "VAULT_ROOT_TOKEN=$ROOT_TOKEN" >> /tmp/vault-credentials
        
        echo ""
        echo "⚠️  IMPORTANT: Save these credentials securely!"
        echo "Root Token: $ROOT_TOKEN"
        echo "Unseal Key: $UNSEAL_KEY"
        echo ""
      else
        echo "ℹ️  Vault is already initialized"
      fi
    EOT
  }
}

# Unseal Vault pods
resource "null_resource" "vault_unseal" {
  depends_on = [null_resource.vault_init]
  
  triggers = {
    deployment_mode = var.deployment_mode
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "🔓 Unsealing Vault..."
      
      if [ ! -f /tmp/vault-credentials ]; then
        echo "⚠️  No credentials found, Vault may already be unsealed"
        exit 0
      fi
      
      . /tmp/vault-credentials
      
      # Unseal based on deployment mode
      if [ "${local.is_ha}" = "true" ]; then
        # Unseal all HA replicas
        for i in 0 1 2; do
          echo "Unsealing vault-$i..."
          kubectl exec -n ${var.namespace} vault-$i -- vault operator unseal $VAULT_UNSEAL_KEY || true
        done
      else
        # Unseal standalone instance
        POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n ${var.namespace} $POD_NAME -- vault operator unseal $VAULT_UNSEAL_KEY
      fi
      
      echo "✅ Vault unsealed successfully"
    EOT
  }
}

# For HA mode: Join and unseal additional nodes
resource "null_resource" "vault_ha_join" {
  count      = local.is_ha ? 1 : 0
  depends_on = [null_resource.vault_unseal]
  
  triggers = {
    deployment_mode = var.deployment_mode
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "🔗 Joining Vault HA cluster..."
      
      source /tmp/vault-credentials
      
      # Join vault-1 and vault-2 to the raft cluster
      for i in 1 2; do
        echo "Joining vault-$i to cluster..."
        
        # Check if already joined
        STATUS=$(kubectl exec -n ${var.namespace} vault-$i -- vault status -format=json 2>/dev/null || echo '{"initialized":false}')
        
        if echo "$STATUS" | jq -e '.initialized == false' > /dev/null; then
          # Join the raft cluster
          if [ "${local.is_tls_enabled}" = "true" ]; then
            kubectl exec -n ${var.namespace} vault-$i -- vault operator raft join \
              -leader-ca-cert=/vault/tls/ca.crt \
              -leader-client-cert=/vault/tls/tls.crt \
              -leader-client-key=/vault/tls/tls.key \
              https://vault-0.vault-internal:8200
          else
            kubectl exec -n ${var.namespace} vault-$i -- vault operator raft join \
              http://vault-0.vault-internal:8200
          fi
          
          # Unseal the joined node
          kubectl exec -n ${var.namespace} vault-$i -- vault operator unseal $VAULT_UNSEAL_KEY
          
          echo "✅ vault-$i joined and unsealed"
        else
          echo "ℹ️  vault-$i already initialized"
        fi
      done
      
      echo "✅ HA cluster configured successfully"
    EOT
  }
}

# Output initialization status
output "init_status" {
  description = "Vault initialization status"
  value       = "Vault initialized and unsealed. Credentials in /tmp/vault-credentials"
  depends_on  = [null_resource.vault_unseal]
}
