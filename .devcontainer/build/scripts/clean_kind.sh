#!/usr/bin/env bash
# Kind clusters cleanup script - handles orphaned clusters not managed by Terraform

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

if command -v kind &> /dev/null; then
    # Get list of existing clusters
    CLUSTERS=$(kind get clusters 2>/dev/null || true)
    if [ -n "$CLUSTERS" ]; then
        echo "  Found existing Kind clusters: $CLUSTERS"
        echo "  Note: Terraform-managed clusters should have been removed in previous step"
        for cluster in $CLUSTERS; do
            echo "  Deleting orphaned Kind cluster: $cluster"
            kind delete cluster --name "$cluster" 2>/dev/null || true
        done
        print_status "Orphaned Kind clusters cleaned"
    else
        print_status "No orphaned Kind clusters found"
    fi
else
    print_status "Kind not installed yet (will be installed later)"
fi