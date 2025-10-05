#!/usr/bin/env bash
# =============================================================================
# Terragrunt Initialization Script
# Initializes Terragrunt and downloads required providers
# =============================================================================

set -e

echo "🚀 Terragrunt Initialization"
echo "============================="
echo ""

# Check if terragrunt is installed
if ! command -v terragrunt &> /dev/null; then
    echo "❌ Terragrunt is not installed!"
    echo ""
    echo "Please install terragrunt:"
    echo "  macOS:   brew install terragrunt"
    echo "  Linux:   https://terragrunt.gruntwork.io/docs/getting-started/install/"
    echo ""
    exit 1
fi

echo "✅ Terragrunt is installed: $(terragrunt --version | head -1)"
echo ""

echo "🔧 Initializing Terragrunt..."
echo "   - Downloading providers"
echo "   - Generating backend configuration"
echo "   - Generating provider configuration"
echo ""

terragrunt init

echo ""
echo "✅ Terragrunt initialization complete!"
echo ""
echo "Next steps:"
echo "  ./apply.sh -auto-approve    # Deploy infrastructure"
echo "  ./destroy.sh -auto-approve  # Destroy infrastructure"
