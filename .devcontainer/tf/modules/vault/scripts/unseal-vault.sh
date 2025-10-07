#!/bin/bash
# Vault Unseal Helper Script
# This script unseals Vault pods using keys stored in Kubernetes secret

set -e

NAMESPACE="${1:-vault}"
POD_NAME="${2}"

echo "🔓 Unsealing Vault in namespace: $NAMESPACE"

# Check if secret exists
if ! kubectl get secret vault-unseal-keys -n "$NAMESPACE" &>/dev/null; then
  echo "❌ Error: vault-unseal-keys secret not found in namespace $NAMESPACE"
  exit 1
fi

# Load unseal keys from secret
echo "🔐 Loading unseal keys from Kubernetes secret..."
KEYS=()
for i in {0..4}; do
  KEY=$(kubectl get secret vault-unseal-keys -n "$NAMESPACE" -o jsonpath="{.data.unseal-key-$i}" 2>/dev/null | base64 -d || echo "")
  if [ -n "$KEY" ]; then
    KEYS+=("$KEY")
  fi
done

if [ ${#KEYS[@]} -lt 3 ]; then
  echo "❌ Error: Found only ${#KEYS[@]} keys, need at least 3"
  exit 1
fi

echo "✅ Loaded ${#KEYS[@]} unseal keys"

# Determine which pods to unseal
if [ -n "$POD_NAME" ]; then
  PODS=("$POD_NAME")
else
  # Unseal all Vault pods
  mapfile -t PODS < <(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
fi

if [ ${#PODS[@]} -eq 0 ]; then
  echo "❌ No Vault pods found"
  exit 1
fi

# Unseal each pod
for pod in "${PODS[@]}"; do
  echo ""
  echo "Unsealing $pod..."
  
  # Check if already unsealed
  if kubectl exec -n "$NAMESPACE" "$pod" -- vault status 2>&1 | grep -q "Sealed.*false"; then
    echo "✅ $pod is already unsealed"
    continue
  fi
  
  # Apply first 3 keys
  kubectl exec -n "$NAMESPACE" "$pod" -- sh -c "
    vault operator unseal '${KEYS[0]}' > /dev/null
    vault operator unseal '${KEYS[1]}' > /dev/null
    vault operator unseal '${KEYS[2]}'
  "
  
  echo "✅ $pod unsealed successfully"
done

echo ""
echo "🎉 Unseal complete!"
