#!/usr/bin/env bash
set -e

# =============================================================================
# DevContainer Post-Create Command Script
# Optimized for quick setup with essential cleanup
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"

# Source centralized environment configuration
source "$SCRIPT_DIR/env.sh"

echo "🚀 Starting DevContainer setup process..."
echo ""

# Step 1: Essential Cleanup (Docker + KIND)
echo "🧹 Step 1: Essential Cleanup"
echo "============================"
echo "Cleaning Docker and KIND resources..."

# Ensure scripts are executable
chmod +x "$SCRIPT_DIR/scripts"/*.sh

# Source common functions
source "$SCRIPT_DIR/scripts/common.sh"

# Only run essential cleanup
"$SCRIPT_DIR/scripts/clean_docker.sh"
"$SCRIPT_DIR/scripts/clean_kind.sh"
"$SCRIPT_DIR/scripts/clean_conflicts.sh"
echo ""

# Step 2: Shell Environment Setup
echo "📝 Step 2: Shell Environment"
echo "============================"
sed -i 's/plugins=(git)/plugins=(docker kubectl kubectx)/' ~/.zshrc 2>/dev/null || true
tofu -install-autocomplete 2>/dev/null || true
terragrunt --install-autocomplete 2>/dev/null || true
print_status "Shell environment configured"
echo ""

# Step 3: Tool Installation
echo "🔧 Step 3: Tool Installation"
echo "============================"
go install sigs.k8s.io/kind@latest
go install sigs.k8s.io/cloud-provider-kind@latest
"$SCRIPT_DIR/scripts/install_cilium_tools.sh"
print_status "Tools installed"
echo ""

# Step 4: Infrastructure Deployment
echo "☸️  Step 4: Kubernetes Infrastructure"
echo "====================================="
cd "$TERRAFORM_ROOT"

# Ensure directories exist
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR" "$TERRAGRUNT_CACHE_DIR"

# Initialize Terragrunt
echo "🔧 Initializing Terragrunt..."
terragrunt init -upgrade

# Deploy with apply.sh (handles 3-stage bootstrap automatically)
echo ""
echo "🚀 Deploying infrastructure..."
"$TERRAFORM_ROOT/apply.sh" -auto-approve

echo ""
echo "✅ DevContainer setup completed successfully!"
echo "============================================="
echo ""
echo "Quick commands:"
echo "  ./tg cluster-info    # Show cluster details"
echo "  ./tg vault-ui        # Access Vault UI"
echo "  ./tg traefik-ui      # Access Traefik dashboard"
echo "  k9s                  # Kubernetes TUI"
