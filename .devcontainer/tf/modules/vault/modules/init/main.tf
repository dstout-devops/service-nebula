# Vault Initialization Submodule
# Handles automated initialization and unsealing of Vault

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Wait for Vault pods to be ready
resource "null_resource" "wait_for_vault" {
  triggers = {
    deployment_mode = var.deployment_mode
    timestamp       = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "⏳ Waiting for Vault pods to be running..."
      
      RETRY=0
      MAX_RETRIES=60
      while [ $RETRY -lt $MAX_RETRIES ]; do
        POD_COUNT=$(kubectl get pods -n ${var.namespace} \
          -l app.kubernetes.io/name=vault,app.kubernetes.io/instance=vault \
          --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$POD_COUNT" -gt 0 ]; then
          echo "✅ Vault pod(s) are running (found $POD_COUNT)"
          break
        fi
        echo "  Waiting for Vault pods... ($RETRY/$MAX_RETRIES)"
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
      if [ "${var.is_tls_enabled}" = "true" ]; then
        export VAULT_ADDR='https://${var.service_name}.${var.namespace}.svc.cluster.local:8200'
        export VAULT_SKIP_VERIFY=1
      else
        export VAULT_ADDR='http://${var.service_name}.${var.namespace}.svc.cluster.local:8200'
      fi
      
      # Check if already initialized
      POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
      
      if kubectl exec -n ${var.namespace} $POD_NAME -- vault status 2>&1 | grep -q "Sealed.*true\|Initialized.*false"; then
        echo "Initializing Vault..."
        
        # Determine key shares based on deployment mode
        KEY_SHARES=${var.is_ha ? 5 : 1}
        KEY_THRESHOLD=${var.is_ha ? 3 : 1}
        
        echo "Initializing with $KEY_SHARES key shares (threshold: $KEY_THRESHOLD)..."
        kubectl exec -n ${var.namespace} $POD_NAME -- vault operator init \
          -key-shares=$KEY_SHARES \
          -key-threshold=$KEY_THRESHOLD \
          -format=json > /tmp/vault-init-keys.json
        
        echo "✅ Vault initialized successfully"
        
        # Save credentials
        ROOT_TOKEN=$(cat /tmp/vault-init-keys.json | jq -r '.root_token')
        echo "VAULT_ROOT_TOKEN=$ROOT_TOKEN" > /tmp/vault-credentials
        
        for i in $(seq 0 $(($KEY_SHARES - 1))); do
          UNSEAL_KEY=$(cat /tmp/vault-init-keys.json | jq -r ".unseal_keys_b64[$i]")
          echo "VAULT_UNSEAL_KEY_$i=$UNSEAL_KEY" >> /tmp/vault-credentials
        done
        
        # Save to Kubernetes secret
        echo "💾 Saving credentials to Kubernetes secret..."
        kubectl create secret generic ${var.unseal_keys_secret_name} \
          -n ${var.namespace} \
          --from-literal=root-token="$ROOT_TOKEN" \
          --dry-run=client -o yaml | kubectl apply -f -
        
        for i in $(seq 0 $(($KEY_SHARES - 1))); do
          UNSEAL_KEY=$(cat /tmp/vault-init-keys.json | jq -r ".unseal_keys_b64[$i]")
          kubectl patch secret ${var.unseal_keys_secret_name} -n ${var.namespace} \
            --type=json \
            -p="[{\"op\": \"add\", \"path\": \"/data/unseal-key-$i\", \"value\": \"$(echo -n $UNSEAL_KEY | base64 -w 0)\"}]"
        done
        
        echo "✅ Credentials saved to secret/${var.unseal_keys_secret_name}"
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
      
      # Load credentials from temp file or Kubernetes secret
      if [ -f /tmp/vault-credentials ]; then
        . /tmp/vault-credentials
      elif kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} &>/dev/null; then
        VAULT_ROOT_TOKEN=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath='{.data.root-token}' | base64 -d)
        export VAULT_ROOT_TOKEN
        for i in 0 1 2 3 4; do
          KEY=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath="{.data.unseal-key-$i}" 2>/dev/null | base64 -d || echo "")
          if [ -n "$KEY" ]; then
            eval "export VAULT_UNSEAL_KEY_$i='$KEY'"
          fi
        done
      else
        echo "⚠️  No credentials found, Vault may already be unsealed"
        exit 0
      fi
      
      # Unseal based on deployment mode
      if [ "${var.is_ha}" = "true" ]; then
        echo "HA mode - unsealing vault-0..."
        kubectl exec -n ${var.namespace} vault-0 -- sh -c "
          vault operator unseal '$VAULT_UNSEAL_KEY_0' > /dev/null
          vault operator unseal '$VAULT_UNSEAL_KEY_1' > /dev/null
          vault operator unseal '$VAULT_UNSEAL_KEY_2'
        "
        echo "✅ vault-0 unsealed"
      else
        POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
        kubectl exec -n ${var.namespace} $POD_NAME -- vault operator unseal $VAULT_UNSEAL_KEY_0
        echo "✅ Vault unsealed"
      fi
    EOT
  }
}

# HA cluster join and unseal
resource "null_resource" "vault_ha_join" {
  count      = var.is_ha ? 1 : 0
  depends_on = [null_resource.vault_unseal]

  triggers = {
    deployment_mode = var.deployment_mode
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "🔗 Joining Vault HA cluster..."
      
      # Load credentials
      if [ -f /tmp/vault-credentials ]; then
        . /tmp/vault-credentials
      elif kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} &>/dev/null; then
        VAULT_ROOT_TOKEN=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath='{.data.root-token}' | base64 -d)
        export VAULT_ROOT_TOKEN
        for i in 0 1 2 3 4; do
          KEY=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath="{.data.unseal-key-$i}" 2>/dev/null | base64 -d || echo "")
          if [ -n "$KEY" ]; then
            eval "export VAULT_UNSEAL_KEY_$i='$KEY'"
          fi
        done
      else
        echo "❌ No credentials found!"
        exit 1
      fi
      
      # Join vault-1 and vault-2
      for i in 1 2; do
        echo "Joining vault-$i..."
        
        STATUS=$(kubectl exec -n ${var.namespace} vault-$i -- vault status -format=json 2>/dev/null || echo '{"initialized":false}')
        
        if echo "$STATUS" | jq -e '.initialized == false' > /dev/null; then
          LEADER_ADDR="${var.vault_protocol}://vault-0.${var.internal_service_name}:8200"
          
          if [ "${var.is_tls_enabled}" = "true" ]; then
            kubectl exec -n ${var.namespace} vault-$i -- sh -c "vault operator raft join \
              -leader-ca-cert=\"\$(cat ${var.userconfig_path}/vault.ca)\" \
              -leader-client-cert=\"\$(cat ${var.userconfig_path}/vault.crt)\" \
              -leader-client-key=\"\$(cat ${var.userconfig_path}/vault.key)\" \
              $LEADER_ADDR"
          else
            kubectl exec -n ${var.namespace} vault-$i -- vault operator raft join $LEADER_ADDR
          fi
          
          echo "  Unsealing vault-$i..."
          kubectl exec -n ${var.namespace} vault-$i -- sh -c "
            vault operator unseal '$VAULT_UNSEAL_KEY_0' > /dev/null
            vault operator unseal '$VAULT_UNSEAL_KEY_1' > /dev/null
            vault operator unseal '$VAULT_UNSEAL_KEY_2'
          "
          
          echo "✅ vault-$i joined and unsealed"
        else
          echo "ℹ️  vault-$i already initialized"
        fi
      done
      
      echo "✅ HA cluster configured"
    EOT
  }
}
