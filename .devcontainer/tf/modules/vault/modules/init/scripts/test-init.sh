#!/bin/sh
# Quick test script for vault-init.sh
# This allows testing the script logic outside of Kubernetes

# Mock template variables for local testing
export namespace="vault"
export is_ha="false"
export is_tls_enabled="false"
export service_name="vault"
export internal_service_name="vault-internal"
export vault_protocol="http"
export userconfig_path="/vault/userconfig"
export unseal_keys_secret_name="vault-unseal-keys"

echo "======================================"
echo "Testing vault-init.sh script locally"
echo "======================================"
echo ""
echo "NOTE: This is for syntax/logic testing only."
echo "Kubectl commands will fail without a real cluster."
echo ""

# Source the script
sh -n ./vault-init.sh

if [ $? -eq 0 ]; then
    echo "✅ Script syntax is valid!"
else
    echo "❌ Script syntax error found"
    exit 1
fi

echo ""
echo "To test with a real cluster, set these environment variables:"
echo "  namespace, is_ha, is_tls_enabled, service_name,"
echo "  internal_service_name, vault_protocol, userconfig_path,"
echo "  unseal_keys_secret_name"
echo ""
echo "Then run: ./vault-init.sh"
