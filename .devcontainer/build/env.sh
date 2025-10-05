# DevContainer Environment Configuration
# This file contains centralized environment variable declarations
# Source this file in scripts that need these variables

# =============================================================================
# Terraform/OpenTofu Configuration
# =============================================================================
export TF_DATA_DIR="/tmp/.terraform"
export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugins"

# =============================================================================
# Terragrunt Configuration
# =============================================================================
export TERRAGRUNT_CACHE_DIR="$HOME/.terragrunt-cache"
export TERRAGRUNT_DOWNLOAD="$TERRAGRUNT_CACHE_DIR"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

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
export KIND_REGISTRY_MGMT_ROOT="tmp/kind-registry-mgmt/"

# =============================================================================
# Cleanup Configuration
# =============================================================================
export CLEANUP_DOCKER_IMAGES="true"  # Set to "false" to preserve Docker images
export BACKUP_KUBE_CONFIG="true"     # Set to "false" to skip kubectl config backup

# =============================================================================
# Directory Creation
# =============================================================================
# Ensure essential directories exist
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR" "$KUBECONFIG_DIR" "$KIND_REGISTRY_MGMT_ROOT" "$TERRAGRUNT_CACHE_DIR"
chmod 700 -R "$KIND_REGISTRY_MGMT_ROOT"