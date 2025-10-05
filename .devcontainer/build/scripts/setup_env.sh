#!/usr/bin/env bash
# Environment setup script

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Configure kernel parameters for Cilium and Kind
# These are required to prevent "too many open files" errors with Cilium
print_status "Configuring kernel parameters for Cilium..."
sudo sysctl -w fs.inotify.max_user_watches=524288 >/dev/null
sudo sysctl -w fs.inotify.max_user_instances=512 >/dev/null
print_info "fs.inotify.max_user_watches=524288"
print_info "fs.inotify.max_user_instances=512"

print_status "Fresh environment variables configured"
print_info "TF_DATA_DIR=$TF_DATA_DIR"
print_info "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"
print_info "KUBECONFIG=$KUBECONFIG"