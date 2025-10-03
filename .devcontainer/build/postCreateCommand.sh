#!/usr/bin/env bash
set -e

# =============================================================================
# DevContainer Post-Create Command Script
# Primary driver for setting up the development environment
# =============================================================================

SCRIPT_DIR="$(dirname "$0")"

# Source centralized environment configuration
source "$SCRIPT_DIR/env.sh"

echo "🚀 Starting DevContainer setup process..."
echo ""

# Step 1: Run pre-flight check to ensure clean environment
echo "📋 Step 1: Pre-flight Environment Check"
echo "========================================="
echo "🚀 Starting pre-flight check for clean development environment..."
echo ""

# Ensure all scripts are executable
chmod +x "$SCRIPT_DIR/scripts"/*.sh

# Source common functions for consistent output
source "$SCRIPT_DIR/scripts/common.sh"

# 1.1: Clean Terraform/OpenTofu managed infrastructure (most comprehensive cleanup)
echo "🏗️  Step 1.1: Terraform/OpenTofu Infrastructure Cleanup"
echo "-----------------------------------------------------"
"$SCRIPT_DIR/scripts/clean_terraform.sh"
echo ""

# 1.2: Clean any remaining Kind clusters (catch orphaned clusters)
echo "🎡 Step 1.2: Kind Clusters Cleanup (Orphaned)"
echo "---------------------------------------------"
"$SCRIPT_DIR/scripts/clean_kind.sh"
echo ""

# 1.3: Clean remaining Docker resources (containers, images, networks)
echo "🐳 Step 1.3: Docker Environment Cleanup"
echo "---------------------------------------"
"$SCRIPT_DIR/scripts/clean_docker.sh"
echo ""

# 1.4: Clean Kubernetes configurations (local kubectl state)
echo "☸️  Step 1.4: Kubernetes Configuration Cleanup"
echo "----------------------------------------------"
"$SCRIPT_DIR/scripts/clean_kube.sh"
echo ""

# 1.5: Clean temporary files and caches
echo "🧹 Step 1.5: Temporary Files and Caches Cleanup"
echo "-----------------------------------------------"
"$SCRIPT_DIR/scripts/clean_temp.sh"
echo ""

# 1.6: Verify clean environment
echo "🔍 Step 1.6: Environment Verification"
echo "------------------------------------"
"$SCRIPT_DIR/scripts/verify_clean.sh"
echo ""

# 1.7: Setup fresh environment
echo "🔧 Step 1.7: Fresh Environment Setup"
echo "-----------------------------------"
"$SCRIPT_DIR/scripts/setup_env.sh"
echo ""

print_status "Pre-flight check completed successfully!"
echo "Environment is clean and ready for fresh development"

echo ""
echo "📝 Step 2: Shell Environment Setup"
echo "==================================="
echo "Configuring shell environment..."
sed -i 's/plugins=(git)/plugins=(docker kubectl kubectx)/' ~/.zshrc
tofu -install-autocomplete 2>/dev/null || true

echo ""
echo "🔧 Step 3: Tool Installation"
echo "============================"
echo "Installing kind and cloud-provider-kind..."
go install sigs.k8s.io/kind@latest
go install sigs.k8s.io/cloud-provider-kind@latest

echo ""
echo "🛠️  Step 3.1: Cilium and Hubble CLI Installation"
echo "==============================================="
echo "Installing Cilium and Hubble CLI tools..."
"$SCRIPT_DIR/scripts/install_cilium_tools.sh"

echo ""
echo "☸️  Step 4: Kubernetes Infrastructure Setup"
echo "==========================================="
echo "Creating kind cluster 'mgmt' with OpenTofu..."
cd "$TERRAFORM_ROOT"

# Environment variables are already set by centralized env.sh (Step 1.7)
# Directories are already created, just ensure they exist
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR"

# Initialize and apply
tofu init
tofu apply -auto-approve

echo ""
echo "✅ DevContainer setup completed successfully!"
echo "================================================"