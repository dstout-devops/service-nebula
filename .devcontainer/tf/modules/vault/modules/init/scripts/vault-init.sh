#!/bin/sh
set -euo pipefail

# Vault Initialization and Unseal Script
# This script runs inside a Kubernetes Job to initialize and unseal Vault
# It uses the service account token for in-cluster authentication

echo "=========================================="
echo "🔐 Vault Initialization and Unseal"
echo "=========================================="
echo ""

# Configuration from Terraform template
NAMESPACE="${namespace}"
IS_HA="${is_ha}"
IS_TLS_ENABLED="${is_tls_enabled}"
SERVICE_NAME="${service_name}"
INTERNAL_SERVICE_NAME="${internal_service_name}"
VAULT_PROTOCOL="${vault_protocol}"
USERCONFIG_PATH="${userconfig_path}"
UNSEAL_KEYS_SECRET_NAME="${unseal_keys_secret_name}"

# Step 1: Wait for Vault pods to be running (not necessarily ready - they won't be ready until unsealed)
echo "⏳ Step 1: Waiting for Vault container(s) to be running..."
echo "  (This may take several minutes for container image pulls on first run)"
echo "  Note: Vault containers will show 0/1 Ready until they are unsealed by this script"
RETRY=0
MAX_RETRIES=180  # 15 minutes (180 * 5 seconds = 900 seconds)

while [ $RETRY -lt $MAX_RETRIES ]; do
  # Check for vault containers that are running (started=true), not necessarily ready
  # The container won't be "ready" until it's unsealed, which is what we're about to do
  # We need to check: 1) Pod phase is Running, 2) containerStatuses exists, 3) vault container started=true
  RUNNING_COUNT=$(kubectl get pods -n "$NAMESPACE" \
    -l app.kubernetes.io/name=vault,app.kubernetes.io/instance=vault \
    -o json 2>/dev/null | \
    jq -r '.items[] | select(.status.phase=="Running") | select(.status.containerStatuses != null) | .status.containerStatuses[] | select(.name=="vault") | select(.started==true) | .name' 2>/dev/null | \
    wc -l)
  
  if [ "$RUNNING_COUNT" -gt 0 ]; then
    echo "✅ Vault container(s) are running (found $RUNNING_COUNT)"
    echo "  Containers will show 0/1 Ready until unsealed - this is expected"
    
    # Verify we can actually exec into the first pod before proceeding
    echo "  Verifying container is ready for exec..."
    FIRST_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n "$NAMESPACE" "$FIRST_POD" -c vault -- echo "ready" &>/dev/null; then
      echo "  ✅ Container exec verified"
      sleep 3
      break
    else
      echo "  ⏳ Container not ready for exec yet, continuing to wait..."
    fi
  fi
  
  # Show current pod status every 12 iterations (1 minute)
  if [ $((RETRY % 12)) -eq 0 ]; then
    echo "  ⏱️  Waiting for Vault containers to start... ($RETRY/$MAX_RETRIES) - Elapsed: $((RETRY * 5 / 60)) min"
    # Show pod status for visibility
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault 2>/dev/null || true
  fi
  
  sleep 5
  RETRY=$((RETRY + 1))
done

if [ $RETRY -ge $MAX_RETRIES ]; then
  echo "❌ Timeout waiting for Vault containers after $((MAX_RETRIES * 5 / 60)) minutes"
  echo ""
  echo "Current pod status:"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o wide || true
  echo ""
  echo "Pod describe output:"
  kubectl describe pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault || true
  exit 1
fi

# Step 2: Configure Vault address
echo ""
echo "🌐 Step 2: Configuring Vault address..."
if [ "$IS_TLS_ENABLED" = "true" ]; then
  export VAULT_ADDR="https://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:8200"
  export VAULT_SKIP_VERIFY=1
  echo "  Using HTTPS: $VAULT_ADDR (skip verify enabled)"
else
  export VAULT_ADDR="http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:8200"
  echo "  Using HTTP: $VAULT_ADDR"
fi

# Get the first Vault pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=vault \
  -o jsonpath='{.items[0].metadata.name}')
echo "  Primary pod: $POD_NAME"

# Step 3: Check if Vault is initialized
echo ""
echo "🔍 Step 3: Checking Vault initialization status..."
# Check initialization status - vault status returns exit code 2 when not initialized
VAULT_INITIALIZED=false
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -c vault -- vault status -format=json 2>/dev/null | jq -e '.initialized == true' > /dev/null 2>&1; then
  VAULT_INITIALIZED=true
fi

if [ "$VAULT_INITIALIZED" = "false" ]; then
  echo "🔐 Vault is not initialized. Initializing now..."
  
  # Determine key shares and threshold based on HA mode
  if [ "$IS_HA" = "true" ]; then
    KEY_SHARES=5
    KEY_THRESHOLD=3
    echo "  HA mode: using $KEY_SHARES key shares with threshold $KEY_THRESHOLD"
  else
    KEY_SHARES=1
    KEY_THRESHOLD=1
    echo "  Standalone mode: using $KEY_SHARES key share"
  fi
  
  # Initialize Vault
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -c vault -- \
    vault operator init \
    -key-shares=$KEY_SHARES \
    -key-threshold=$KEY_THRESHOLD \
    -format=json > /tmp/vault-init-keys.json
  
  # Extract root token
  ROOT_TOKEN=$(jq -r '.root_token' /tmp/vault-init-keys.json)
  
  # Create Kubernetes secret with root token
  echo "  Creating Kubernetes secret: $UNSEAL_KEYS_SECRET_NAME"
  kubectl create secret generic "$UNSEAL_KEYS_SECRET_NAME" \
    -n "$NAMESPACE" \
    --from-literal=root-token="$ROOT_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Store unseal keys in the secret
  for i in $(seq 0 $((KEY_SHARES - 1))); do
    UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" /tmp/vault-init-keys.json)
    # Base64 encode the key for storage
    ENCODED_KEY=$(echo -n "$UNSEAL_KEY" | base64 | tr -d '\n')
    kubectl patch secret "$UNSEAL_KEYS_SECRET_NAME" -n "$NAMESPACE" \
      --type=json \
      -p="[{\"op\": \"add\", \"path\": \"/data/unseal-key-$i\", \"value\": \"$ENCODED_KEY\"}]" || true
    echo "  Stored unseal key $i"
  done
  
  echo "✅ Vault initialized and credentials stored"
else
  echo "ℹ️  Vault is already initialized"
fi

# Step 4: Load unseal keys from secret
echo ""
echo "🔑 Step 4: Loading unseal keys from secret..."
if kubectl get secret "$UNSEAL_KEYS_SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
  ROOT_TOKEN=$(kubectl get secret "$UNSEAL_KEYS_SECRET_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.data.root-token}' | base64 -d)
  export VAULT_TOKEN="$ROOT_TOKEN"
  
  # Load all unseal keys
  for i in 0 1 2 3 4; do
    KEY=$(kubectl get secret "$UNSEAL_KEYS_SECRET_NAME" -n "$NAMESPACE" \
      -o jsonpath="{.data.unseal-key-$i}" 2>/dev/null | base64 -d || echo "")
    if [ -n "$KEY" ]; then
      eval "VAULT_UNSEAL_KEY_$i='$KEY'"
      echo "  Loaded unseal key $i"
    fi
  done
  echo "✅ Unseal keys loaded"
else
  echo "❌ ERROR: Secret $UNSEAL_KEYS_SECRET_NAME not found!"
  echo ""
  echo "This can happen if:"
  echo "  1. Vault was previously initialized but the secret was deleted"
  echo "  2. The cleanup removed the secret but not Vault's data"
  echo ""
  echo "To fix this, you need to either:"
  echo "  A. Restore the secret with the original unseal keys"
  echo "  B. Completely wipe Vault data and re-initialize"
  echo ""
  echo "To completely reset Vault:"
  echo "  1. Delete the Vault StatefulSet/Deployment"
  echo "  2. Delete the Vault PVCs (if any)"
  echo "  3. Re-deploy Vault"
  echo ""
  exit 1
fi

# Step 5: Unseal Vault pods
echo ""
echo "🔓 Step 5: Unsealing Vault..."

if [ "$IS_HA" = "true" ]; then
  echo "  HA mode: unsealing vault-0 (leader)"
  
  # Unseal vault-0 with required number of keys
  kubectl exec -n "$NAMESPACE" vault-0 -c vault -- \
    vault operator unseal "$VAULT_UNSEAL_KEY_0" > /dev/null || true
  kubectl exec -n "$NAMESPACE" vault-0 -c vault -- \
    vault operator unseal "$VAULT_UNSEAL_KEY_1" > /dev/null || true
  kubectl exec -n "$NAMESPACE" vault-0 -c vault -- \
    vault operator unseal "$VAULT_UNSEAL_KEY_2" || true
  
  echo "✅ vault-0 unsealed"
  
  # Step 6: Join and unseal peer nodes
  echo ""
  echo "🔗 Step 6: Joining and unsealing peer nodes..."
  
  for i in 1 2; do
    echo "  Configuring vault-$i..."
    
    # Check if peer is initialized
    STATUS=$(kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- \
      vault status -format=json 2>/dev/null || echo '{"initialized":false}')
    
    if echo "$STATUS" | jq -e '.initialized == false' > /dev/null 2>&1; then
      LEADER_ADDR="$VAULT_PROTOCOL://vault-0.$INTERNAL_SERVICE_NAME:8200"
      echo "    Joining to leader: $LEADER_ADDR"
      
      if [ "$IS_TLS_ENABLED" = "true" ]; then
        # Join with TLS certificates
        kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- sh -c \
          "vault operator raft join \
            -leader-ca-cert=\"\$(cat $USERCONFIG_PATH/vault.ca)\" \
            -leader-client-cert=\"\$(cat $USERCONFIG_PATH/vault.crt)\" \
            -leader-client-key=\"\$(cat $USERCONFIG_PATH/vault.key)\" \
            $LEADER_ADDR" || true
      else
        # Join without TLS
        kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- \
          vault operator raft join "$LEADER_ADDR" || true
      fi
      
      # Unseal the peer
      kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- \
        vault operator unseal "$VAULT_UNSEAL_KEY_0" > /dev/null || true
      kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- \
        vault operator unseal "$VAULT_UNSEAL_KEY_1" > /dev/null || true
      kubectl exec -n "$NAMESPACE" "vault-$i" -c vault -- \
        vault operator unseal "$VAULT_UNSEAL_KEY_2" || true
      
      echo "  ✅ vault-$i joined and unsealed"
    else
      echo "  ℹ️  vault-$i already initialized"
    fi
  done
else
  # Standalone mode - unseal single pod
  echo "  Standalone mode: unsealing $POD_NAME"
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -c vault -- \
    vault operator unseal "$VAULT_UNSEAL_KEY_0" || true
  echo "✅ Vault unsealed"
fi

# Final status check
echo ""
echo "📊 Final Status:"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c vault -- vault status || true

echo ""
echo "=========================================="
echo "✅ Vault initialization complete!"
echo "=========================================="
echo ""
echo "Credentials stored in secret: $UNSEAL_KEYS_SECRET_NAME"
echo "Namespace: $NAMESPACE"
