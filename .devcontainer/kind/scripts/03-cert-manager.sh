#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Script failed at line $LINENO: $BASH_COMMAND"' ERR

helm repo add jetstack https://charts.jetstack.io --force-update

kubectl create namespace cert-manager

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  -f values/cert-manager.yml

kubectl create secret tls int-ca \
  --cert=certs/int-ca.crt \
  --key=certs/int-ca.key \
  -n cert-manager
