#!/usr/bin/env bash
# Temporary files and caches cleanup script

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Clean Go module cache and build cache
if command -v go &> /dev/null; then
    go clean -cache 2>/dev/null || true
    go clean -modcache 2>/dev/null || true
    print_status "Go caches cleaned"
fi

# Clean common temp directories
rm -rf /tmp/kind-* 2>/dev/null || true
rm -rf /tmp/kubernetes-* 2>/dev/null || true
rm -rf /tmp/helm-* 2>/dev/null || true

print_status "Temporary files and caches cleaned"