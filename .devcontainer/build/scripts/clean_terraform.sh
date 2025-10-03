#!/usr/bin/env bash
# Terraform/OpenTofu infrastructure cleanup script
# Primary responsibility: Destroy managed infrastructure (Kind clusters, Helm releases, etc.)

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Change to terraform directory
cd "$TERRAFORM_ROOT"

# Function to safely run terraform/tofu commands
safe_tofu() {
    if command -v tofu &> /dev/null; then
        tofu "$@"
    else
        print_warning "OpenTofu not available, skipping terraform operations"
        return 0
    fi
}

# Try to destroy existing infrastructure first (if state exists)
if [ -f "terraform.tfstate" ] || [ -d ".terraform" ] || [ -d "$TF_DATA_DIR" ]; then
    echo "  Found existing Terraform state, attempting controlled cleanup..."
    
    # Initialize if needed
    safe_tofu init 2>/dev/null || true
    
    # Try to destroy cleanly
    safe_tofu destroy -auto-approve 2>/dev/null || true
    
    print_status "Terraform destroy completed (or skipped if no state)"
fi

# Remove all state files and directories
echo "  Removing all Terraform state files and directories..."
rm -rf .terraform/ 2>/dev/null || true
rm -rf terraform.tfstate* 2>/dev/null || true
rm -rf .terraform.lock.hcl 2>/dev/null || true
rm -rf "$TF_DATA_DIR" 2>/dev/null || true
rm -rf "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || true

# Recreate the directories for next run
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR"

print_status "Terraform/OpenTofu cleanup completed"