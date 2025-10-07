#!/usr/bin/env bash
# Kubernetes configurations cleanup script
# Primary responsibility: Clean local kubectl configuration and contexts

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Clean up any leftover Kubernetes resources from previous runs
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    print_status "Cleaning leftover Kubernetes resources..."
    
    # Remove cert-manager RBAC resources that might conflict
    kubectl delete role cert-manager-tokenrequest -n cert-manager 2>/dev/null && print_info "Removed cert-manager-tokenrequest role" || true
    kubectl delete rolebinding cert-manager-tokenrequest -n cert-manager 2>/dev/null && print_info "Removed cert-manager-tokenrequest rolebinding" || true
    
    # Remove any other common leftover resources
    kubectl delete clusterrole cert-manager-tokenrequest 2>/dev/null || true
    kubectl delete clusterrolebinding cert-manager-tokenrequest 2>/dev/null || true
    
    print_info "Kubernetes resources cleanup complete"
fi

if [ -d "$KUBECONFIG_DIR" ]; then
    echo "  Cleaning kubectl config..."
    # Backup existing config if it exists and backup is enabled
    if [ -f "$KUBECONFIG_DIR/config" ] && [ "$BACKUP_KUBE_CONFIG" = "true" ]; then
        cp "$KUBECONFIG_DIR/config" "$KUBECONFIG_DIR/config.backup.$(date +%s)" 2>/dev/null || true
        print_info "Backup created"
    fi
    # Remove all kubectl contexts and configs
    rm -rf "$KUBECONFIG_DIR"/* 2>/dev/null || true
    # Recreate directory for next run
    mkdir -p "$KUBECONFIG_DIR"
    print_status "Kubernetes configurations cleaned"
else
    print_status "No Kubernetes configurations to clean"
fi