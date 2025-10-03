# DevContainer Environment Configuration
# This file contains centralized environment variable declarations
# Source this file in scripts that need these variables

# =============================================================================
# Terraform/OpenTofu Configuration
# =============================================================================
export TF_DATA_DIR="/tmp/.terraform"
export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugins"

# =============================================================================
# Kubernetes Configuration
# =============================================================================
export KUBECONFIG="$HOME/.kube/config"
export KUBECONFIG_DIR="$HOME/.kube"

# =============================================================================
# Development Paths
# =============================================================================
export DEVCONTAINER_ROOT="/workspaces/service-nebula/.devcontainer"
export TERRAFORM_ROOT="$DEVCONTAINER_ROOT/tf"
export SCRIPTS_ROOT="$DEVCONTAINER_ROOT/build/scripts"

# =============================================================================
# Cleanup Configuration
# =============================================================================
export CLEANUP_DOCKER_IMAGES="true"  # Set to "false" to preserve Docker images
export BACKUP_KUBE_CONFIG="true"     # Set to "false" to skip kubectl config backup

# =============================================================================
# Directory Creation
# =============================================================================
# Ensure essential directories exist
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR" "$KUBECONFIG_DIR"