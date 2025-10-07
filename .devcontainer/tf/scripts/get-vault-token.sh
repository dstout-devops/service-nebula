#!/bin/bash
# get-vault-token.sh
# Gets a Vault token - either from file (root token for Stage 2) or via Kubernetes auth (for Stage 3+)

set -euo pipefail

VAULT_TOKEN_FILE=".vault-token"
VAULT_ADDR="${VAULT_ADDR:-https://localhost:8200}"
TERRAFORM_SA_NAMESPACE="${TERRAFORM_SA_NAMESPACE:-default}"
TERRAFORM_SA_NAME="${TERRAFORM_SA_NAME:-terraform}"
TERRAFORM_ROLE="${TERRAFORM_ROLE:-terraform}"

# Check if we should use root token (Stage 2) or Kubernetes auth (Stage 3+)
USE_ROOT_TOKEN="${USE_ROOT_TOKEN:-false}"

if [ "$USE_ROOT_TOKEN" = "true" ]; then
    # Stage 2: Use root token to set up Kubernetes auth
    echo "Using root token from Kubernetes secret..." >&2
    kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d
else
    # Stage 3+: Use Kubernetes auth for short-lived token
    echo "Authenticating via Kubernetes auth..." >&2
    
    # Get the service account token
    SA_TOKEN=$(kubectl create token "$TERRAFORM_SA_NAME" -n "$TERRAFORM_SA_NAMESPACE" --duration=3600s)
    
    # Login to Vault and get a short-lived token
    VAULT_TOKEN=$(curl -sk "$VAULT_ADDR/v1/auth/kubernetes/login" \
        -d "{\"jwt\": \"$SA_TOKEN\", \"role\": \"$TERRAFORM_ROLE\"}" | \
        jq -r '.auth.client_token')
    
    if [ "$VAULT_TOKEN" = "null" ] || [ -z "$VAULT_TOKEN" ]; then
        echo "ERROR: Failed to authenticate with Vault via Kubernetes auth" >&2
        exit 1
    fi
    
    echo "Got short-lived token (TTL: 1h)" >&2
    echo "$VAULT_TOKEN"
fi
