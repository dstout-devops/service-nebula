#!/usr/bin/env bash
# =============================================================================
# Three-Stage Terragrunt Apply
#
# Stage 1: Registry + Cluster (Docker provider only)
#   - Creates KIND cluster and registry proxy
#   - Kubernetes context becomes available
#
# Stage 2: Core Kubernetes Resources (Kubernetes providers available)
#   - Deploys Cilium CNI, metrics-server, cert-manager
#   - Deploys Vault Helm release and initializes it
#   - Waits for Vault and extracts VAULT_TOKEN
#
# Stage 3: Vault PKI + Applications (All providers including Vault)
#   - Configures Vault PKI engine
#   - Sets up cert-manager integration with Vault
#   - Deploys remaining applications (Traefik, etc.)
# =============================================================================

set -e

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Cleanup function for background processes
cleanup() {
    if [ -n "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "🚀 Three-Stage Terragrunt Apply"
echo "================================"
echo "Working directory: $SCRIPT_DIR"
echo ""

# Step 0: Clean up any resource conflicts
echo "🧹 Checking for resource conflicts..."
if [ -f "$SCRIPT_DIR/../.devcontainer/build/scripts/clean_conflicts.sh" ]; then
    "$SCRIPT_DIR/../.devcontainer/build/scripts/clean_conflicts.sh"
elif [ -f "$(dirname "$SCRIPT_DIR")/.devcontainer/build/scripts/clean_conflicts.sh" ]; then
    "$(dirname "$SCRIPT_DIR")/.devcontainer/build/scripts/clean_conflicts.sh"
else
    echo "⚠️  Conflict resolution script not found, continuing..."
fi
echo ""

# Check if cluster already exists
CLUSTER_EXISTS=$(kind get clusters 2>/dev/null | grep -c "^mgmt$" || true)

if [ "$CLUSTER_EXISTS" -eq 1 ]; then
    echo "✅ Cluster exists - setting up Vault connection..."
    
    # Set up Vault connection if running
    if kubectl get pods -n vault -l app.kubernetes.io/name=vault 2>/dev/null | grep -q Running; then
        kubectl port-forward -n vault svc/vault 8200:8200 >/dev/null 2>&1 &
        PORT_FORWARD_PID=$!
        sleep 2
        export VAULT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d || echo "")
        [ -n "$VAULT_TOKEN" ] && echo "✅ Vault token configured"
    fi
    
    echo "Running terragrunt apply..."
    terragrunt apply "$@"
    exit 0
fi

echo "📦 New cluster - running three-stage bootstrap..."
echo ""

# Note: Registry directories are created and managed by Terraform null_resource
# See modules/kind-cluster/registry-proxy.tf for directory setup
# If you encounter permission errors, run: ../build/scripts/clean_conflicts.sh

# =============================================================================
# Stage 1: Registry + Cluster
# Only Docker provider is available at this stage
# Creates the cluster so Kubernetes provider can connect
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Stage 1: Registry + KIND Cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Providers: Docker only"
echo ""

terragrunt apply \
    -target=module.registry_proxy \
    -target=module.mgmt_cluster \
    "$@"

echo ""
echo "✅ Stage 1 complete - Kubernetes context available"
echo ""

# =============================================================================
# Stage 2: Core Kubernetes Resources (CNI, Apps, Vault Deployment)
# Kubernetes provider is now available (cluster exists)
# Deploys Vault but doesn't configure PKI yet (no VAULT_TOKEN)
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Stage 2: Core Kubernetes Resources + Vault"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Providers: Docker, Kubernetes, Helm, Kubectl"
echo ""

terragrunt apply \
    -target=module.mgmt_cilium \
    -target=module.mgmt_metrics_server \
    -target=module.mgmt_cert_manager \
    -target=module.mgmt_vault.kubernetes_namespace.vault \
    -target=module.mgmt_vault.module.tls \
    -target=module.mgmt_vault.helm_release.vault \
    -target=module.mgmt_vault.module.init \
    "$@"

# Wait for Vault
echo ""
echo "⏳ Waiting for Vault initialization..."
for i in {1..30}; do
    if kubectl get secret vault-unseal-keys -n vault >/dev/null 2>&1; then
        echo "✅ Vault initialized and unsealed"
        break
    fi
    [ $i -eq 30 ] && echo "❌ Timeout waiting for Vault" && exit 1
    sleep 5
done

# Setup Vault connection
echo ""
echo "🔌 Setting up Vault connection..."
kubectl port-forward -n vault svc/vault 8200:8200 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
export VAULT_TOKEN=$(kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d)
echo "✅ Vault token: ${VAULT_TOKEN:0:10}..."
echo ""
echo "✅ Stage 2 complete - Vault provider available"
echo ""

# =============================================================================
# Stage 3: Vault PKI Resources + Remaining Components
# All providers available including Vault (VAULT_TOKEN is set)
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Stage 3: Vault PKI + Applications"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Providers: Docker, Kubernetes, Helm, Kubectl, Vault"
echo ""

terragrunt apply "$@"

echo ""
echo "✅ Three-stage bootstrap complete!"

echo ""
echo "Cluster details:"
echo "  Name: mgmt"
echo "  Context: kind-mgmt"
echo ""
echo "Quick commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  k9s"
