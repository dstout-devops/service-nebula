#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Script failed at line $LINENO: $BASH_COMMAND"' ERR

helm repo add hashicorp https://helm.releases.hashicorp.com --force-update

kubectl create namespace vault
kubectl apply -f manifests/vault-cert.yml

helm install vault hashicorp/vault \
    --namespace vault \
    --create-namespace \
    --kube-context kind-na \
    -f values/vault-na.yml

NAMESPACE="vault"
SECRET_NAME="vault-init-keys"

# Check if already initialized
if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} &>/dev/null; then
  echo "Vault already initialized."
  exit 0
fi

POD=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}")

# Initialize
INIT_OUTPUT=$(kubectl exec -n ${NAMESPACE} $POD -- vault operator init -format=json)
UNSEAL_KEYS=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]')
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

# Save to Kubernetes Secret
kubectl create secret generic ${SECRET_NAME} -n ${NAMESPACE} \
  --from-literal=root_token=${ROOT_TOKEN} \
  $(for i in {1..3}; do echo --from-literal=unseal_key_$i=$(echo "$UNSEAL_KEYS" | sed -n "${i}p"); done)

# Unseal
echo "$UNSEAL_KEYS" | while read -r key; do
  kubectl exec -n ${NAMESPACE} $POD -- vault operator unseal "$key"
done

kubectl get secret vault-init-keys -n vault -o jsonpath='{.data.root_token}' | base64 -d > root-token

POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath="{.items[0].metadata.name}")

kubectl cp root-token vault/$POD:/vault/root-token
kubectl cp scripts/vault/enable-pki.sh vault/$POD:/vault/enable-pki.sh
kubectl exec -n vault $POD -- sh /vault/enable-pki.sh

kubectl cp scripts/vault/generate-csr.sh vault/$POD:/vault/
kubectl exec -n vault $POD -- sh /vault/generate-csr.sh
kubectl cp vault/$POD:/vault/vault-intermediate.json vault-intermediate.json