#!/usr/bin/env bash
# Environment setup script

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

print_status "Fresh environment variables configured"
print_info "TF_DATA_DIR=$TF_DATA_DIR"
print_info "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"
print_info "KUBECONFIG=$KUBECONFIG"