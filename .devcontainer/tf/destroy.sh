#!/usr/bin/env bash
# =============================================================================
# Simplified Terragrunt Destroy
# =============================================================================

set -e

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🗑️  Terragrunt Destroy"
echo "===================="
echo "Working directory: $SCRIPT_DIR"
echo ""

# Set up Vault connection if cluster exists
if kind get clusters 2>/dev/null | grep -q "^mgmt$"; then
    if kubectl get pods -n vault -l app.kubernetes.io/name=vault 2>/dev/null | grep -q Running; then
        echo "🔌 Setting up Vault connection..."
        kubectl port-forward -n vault svc/vault 8200:8200 >/dev/null 2>&1 &
        PORT_FORWARD_PID=$!
        sleep 2
        export VAULT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d || echo "")
        trap "kill $PORT_FORWARD_PID 2>/dev/null || true" EXIT
    fi
fi

terragrunt destroy "$@"

echo ""
echo "✅ Destroy complete!"
