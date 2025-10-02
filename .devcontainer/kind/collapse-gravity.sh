#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo $DIR
cd "$DIR"

bash scripts/01-gen-root-ca.sh
bash scripts/02-kind-up.sh

# # cert-manager
# kubectl create namespace cert-manager
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
# helm repo add jetstack https://charts.jetstack.io --force-update
# helm install cert-manager jetstack/cert-manager \
#    --namespace cert-manager
# # In order to begin issuing certificates, you will need to set up a ClusterIssuer
# # or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

# # kubernetes metrics server
# helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
# helm install metrics-server metrics-server/metrics-server

# # traefik
# helm repo add traefik https://traefik.github.io/charts --force-update
# kubectl create namespace traefik
# helm install traefik traefik/traefik \
#    --namespace=traefik \
#    --set ingressRoute.dashboard.enabled=true