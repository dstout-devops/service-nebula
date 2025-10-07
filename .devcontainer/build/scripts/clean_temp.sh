#!/usr/bin/env bash
# Temporary files and caches cleanup script

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Clean Go module cache and build cache
if command -v go &> /dev/null; then
    go clean -cache 2>/dev/null || true
    go clean -modcache 2>/dev/null || true
    print_status "Go caches cleaned"
fi

# Clean registry configuration files (hosts.toml files for containerd)
# Note: This only removes the config subdirectory, not the actual cache data
print_status "Cleaning registry configuration files..."
if [ -n "$REGISTRY_CACHE_ROOT" ] && [ -d "$REGISTRY_CACHE_ROOT/config" ]; then
    rm -rf "$REGISTRY_CACHE_ROOT/config" 2>/dev/null || true
    print_info "Removed: $REGISTRY_CACHE_ROOT/config/*"
fi

# Note: Registry cache data (/tmp/registry-cache/{docker-io,gcr-io,...}) is persistent
# It's mounted as a Docker volume and should persist across devcontainer rebuilds

print_status "Temporary files and caches cleaned"