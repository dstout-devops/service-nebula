#!/usr/bin/env bash
set -e

# =============================================================================
# DevContainer Post-Create Command Script
# Optimized for quick setup with essential cleanup
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"

# Source centralized environment configuration
source "$(dirname "$0")/env.sh"

echo "🚀 Starting DevContainer setup process..."
echo ""

# Step 0: Fix Script Permissions
echo "🔧 Step 0: Fixing Script Permissions"
echo "====================================="
# Ensure all shell scripts in the devcontainer are executable
find "$DEVCONTAINER_ROOT" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
# Also fix Terraform module scripts
find "$TERRAFORM_ROOT/modules" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
echo "✅ Script permissions fixed"
echo ""

# Step 1: Complete Environment Cleanup
echo "🧹 Step 1: Complete Environment Cleanup"
echo "========================================"
echo "Wiping all existing configurations..."

# Source common functions (scripts are now executable)
source "$SCRIPT_DIR/scripts/common.sh"

# Run cleanup in optimal order: Terraform -> Kind -> Docker -> Kube -> Temp
"$SCRIPT_DIR/scripts/setup_env.sh"
"$SCRIPT_DIR/scripts/clean_terraform.sh"
"$SCRIPT_DIR/scripts/clean_kind.sh"
"$SCRIPT_DIR/scripts/clean_docker.sh"
"$SCRIPT_DIR/scripts/clean_kube.sh"
"$SCRIPT_DIR/scripts/clean_temp.sh"
"$SCRIPT_DIR/scripts/clean_conflicts.sh"
print_status "Complete environment cleanup finished"
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
echo ""
