#!/usr/bin/env bash
# Validation script for OpenTofu configuration

set -e

echo "🔍 Validating OpenTofu configuration..."
echo

cd "$(dirname "$0")"

# Check if tofu is installed
if ! command -v tofu &> /dev/null; then
    echo "❌ OpenTofu (tofu) is not installed"
    exit 1
fi
echo "✅ OpenTofu is installed"

# Initialize without backend
export TF_DATA_DIR="/tmp/.terraform-validate"
mkdir -p "$TF_DATA_DIR"

echo "📦 Initializing..."
tofu init -backend=false > /dev/null 2>&1
echo "✅ Initialization successful"

# Validate configuration
echo "🔎 Validating configuration..."
if tofu validate; then
    echo "✅ Configuration is valid"
else
    echo "❌ Configuration validation failed"
    exit 1
fi

# Format check
echo "📝 Checking formatting..."
if tofu fmt -check -recursive .; then
    echo "✅ Formatting is correct"
else
    echo "⚠️  Formatting issues detected. Run 'tofu fmt -recursive .' to fix"
fi

# Clean up
rm -rf "$TF_DATA_DIR"

echo
echo "🎉 All validation checks passed!"
echo
echo "To apply this configuration:"
echo "  cd .devcontainer/tf"
echo "  export TF_DATA_DIR=\"/tmp/.terraform-mgmt\""
echo "  tofu init"
echo "  tofu plan"
echo "  tofu apply"
