#!/usr/bin/env bash
# Kubernetes configurations cleanup script
# Primary responsibility: Clean local kubectl configuration and contexts

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

if [ -d "$KUBECONFIG_DIR" ]; then
    echo "  Backing up and cleaning kubectl config..."
    # Backup existing config if it exists and backup is enabled
    if [ -f "$KUBECONFIG_DIR/config" ] && [ "$BACKUP_KUBE_CONFIG" = "true" ]; then
        cp "$KUBECONFIG_DIR/config" "$KUBECONFIG_DIR/config.backup.$(date +%s)" 2>/dev/null || true
    fi
    # Remove all kubectl contexts and configs
    rm -rf "$KUBECONFIG_DIR"/*
    print_status "Kubernetes configurations cleaned"
else
    print_status "No Kubernetes configurations to clean"
fi