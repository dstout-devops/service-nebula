#!/usr/bin/env bash
# Environment setup script
# Performs setup actions using environment variables from env.sh

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

print_header "Setting up Environment"

# =============================================================================
# Registry Cache Directory Setup
# =============================================================================
print_status "Setting up registry cache directories..."
# Create registry cache directories with correct ownership
# This must happen BEFORE Terraform runs the registry containers
REGISTRIES=("docker-io" "gcr-io" "ghcr-io" "quay-io" "registry-k8s-io")

for registry in "${REGISTRIES[@]}"; do
    CACHE_DIR="$REGISTRY_CACHE_ROOT/$registry"
    mkdir -p "$CACHE_DIR"
    # Set ownership to vscode user (matches devcontainer UID 1000)
    chown -R vscode:vscode "$CACHE_DIR" 2>/dev/null || sudo chown -R vscode:vscode "$CACHE_DIR"
    chmod -R 755 "$CACHE_DIR"
done

print_info "Registry cache directories created: $REGISTRY_CACHE_ROOT/*"
print_info "Ownership: vscode:vscode (UID 1000), Permissions: 755"

# =============================================================================
# Registry Configuration Directories for Containerd
# =============================================================================
print_status "Setting up registry configuration directories..."
# These directories will hold hosts.toml files for containerd registry mirrors
# They are mounted into KIND nodes at /etc/containerd/certs.d/
REGISTRY_DOMAINS=("docker.io" "gcr.io" "ghcr.io" "quay.io" "registry.k8s.io")

# Create config directory in registry cache root (may need sudo for volume-mounted directory)
sudo mkdir -p "$REGISTRY_CACHE_ROOT/config"
sudo chown -R vscode:vscode "$REGISTRY_CACHE_ROOT/config"

for domain in "${REGISTRY_DOMAINS[@]}"; do
    CONFIG_DIR="$REGISTRY_CACHE_ROOT/config/${domain}"
    mkdir -p "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
done

print_info "Registry config directories created: $REGISTRY_CACHE_ROOT/config/*"
print_info "Terraform will populate with hosts.toml files"

# =============================================================================
# Kernel Parameters for Cilium and Kind
# =============================================================================
# These are required to prevent "too many open files" errors with Cilium
print_status "Configuring kernel parameters for Cilium..."
sudo sysctl -w fs.inotify.max_user_watches=524288 >/dev/null
sudo sysctl -w fs.inotify.max_user_instances=512 >/dev/null
print_info "fs.inotify.max_user_watches=524288"
print_info "fs.inotify.max_user_instances=512"

# =============================================================================
# Environment Summary
# =============================================================================
print_status "Environment configured successfully"
print_info "TF_DATA_DIR=$TF_DATA_DIR"
print_info "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"
print_info "KUBECONFIG=$KUBECONFIG"
print_info "REGISTRY_CACHE_ROOT=$REGISTRY_CACHE_ROOT"