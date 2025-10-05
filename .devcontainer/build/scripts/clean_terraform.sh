#!/usr/bin/env bash
# Terraform/OpenTofu/Terragrunt infrastructure cleanup script
# Primary responsibility: Destroy managed infrastructure (Kind clusters, Helm releases, etc.)

set -e

# Source common functions
source "$(dirname "$0")/common.sh"

# Source centralized environment configuration
source "$(dirname "$0")/../env.sh"

# Change to terraform directory
cd "$TERRAFORM_ROOT"

# Function to safely run terragrunt commands (preferred over direct tofu)
safe_terragrunt() {
    if command -v terragrunt &> /dev/null; then
        terragrunt "$@"
    elif command -v tofu &> /dev/null; then
        print_warning "Terragrunt not available, falling back to OpenTofu"
        tofu "$@"
    else
        print_warning "Neither Terragrunt nor OpenTofu available, skipping operations"
        return 0
    fi
}

# Try to destroy existing infrastructure first (if state exists)
if [ -f "terraform.tfstate" ] || [ -d ".terraform" ] || [ -d "$TF_DATA_DIR" ] || [ -f "terragrunt.hcl" ]; then
    echo "  Found existing Terraform/Terragrunt state, attempting controlled cleanup..."
    
    # Initialize if needed (Terragrunt will handle tofu init automatically)
    safe_terragrunt init 2>/dev/null || true
    
    # Try to destroy cleanly using destroy script (handles Vault cleanup, etc.)
    if [ -x "./destroy.sh" ]; then
        echo "  Using destroy.sh for comprehensive cleanup..."
        ./destroy.sh -auto-approve 2>/dev/null || true
    else
        # Fallback to direct terragrunt destroy
        safe_terragrunt destroy -auto-approve 2>/dev/null || true
    fi
    
    print_status "Terragrunt/Terraform destroy completed (or skipped if no state)"
fi

# Remove all state files and directories (including Terragrunt)
echo "  Removing all Terraform/Terragrunt state files and directories..."
rm -rf .terraform/ 2>/dev/null || true
rm -rf terraform.tfstate* 2>/dev/null || true
rm -rf .terraform.lock.hcl 2>/dev/null || true
rm -rf backend.tf 2>/dev/null || true
rm -rf providers_generated.tf 2>/dev/null || true
rm -rf "$TF_DATA_DIR" 2>/dev/null || true
rm -rf "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || true
rm -rf "$TERRAGRUNT_CACHE_DIR" 2>/dev/null || true

# Recreate the directories for next run
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR" "$TERRAGRUNT_CACHE_DIR"

print_status "Terragrunt/Terraform cleanup completed"