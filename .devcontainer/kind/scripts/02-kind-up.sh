#!/bin/bash
set -euo pipefail

declare -A CLUSTERS
CLUSTERS[1]=kind-na
CLUSTERS[2]=kind-eu

# create our clusters
for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do
  cluster="${CLUSTERS[$index]}"

  config_file="manifests/${cluster}.yml"
  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Missing config file $config_file"
    exit 1
  fi

  echo "Creating ${cluster} cluster"
  if kind get clusters | grep -q "^${cluster#kind-}$"; then
    echo "Cluster ${cluster} already exists, deleting it first"
    kind delete cluster --name ${cluster#kind-}
  fi
  kind create cluster --name ${cluster#kind-} --config manifests/${cluster}.yml
done

#region CILIUM SETUP
helm repo add cilium https://helm.cilium.io/ --force-update

# install cilium-cli
if ! command -v cilium &>/dev/null || [[ "$(cilium version 2>/dev/null | head -n1)" != *"${CILIUM_CLI_VERSION}"* ]]; then
  echo "Installing Cilium CLI version ${CILIUM_CLI_VERSION}..."

  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  GOOS=$(go env GOOS)
  GOARCH=$(go env GOARCH)
  curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}
  sha256sum --check cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum
  sudo tar -C /usr/local/bin -xzvf cilium-${GOOS}-${GOARCH}.tar.gz
  rm cilium-${GOOS}-${GOARCH}.tar.gz*
fi


# install hubble-cli
if ! command -v hubble &>/dev/null || [[ "$(hubble version 2>/dev/null)" != *"${HUBBLE_VERSION}"* ]]; then
  echo "Installing Hubble CLI version ${HUBBLE_VERSION}..."
  HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
  HUBBLE_ARCH=amd64
  curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
  sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
  sudo tar -C /usr/local/bin -xzvf hubble-linux-${HUBBLE_ARCH}.tar.gz
  rm hubble-linux-${HUBBLE_ARCH}.tar.gz*
fi


for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do

  cluster="${CLUSTERS[$index]}"
  echo "Installing cilium to ${cluster} cluster"

  if [[ "$index" -ne 1 ]]; then
    kubectl --context "${CLUSTERS[1]}" get secret -n kube-system cilium-ca -o yaml | kubectl --context "${cluster}" create -f -
  fi

  helm install cilium cilium/cilium \
    --namespace kube-system \
    --set image.pullPolicy=IfNotPresent \
    --set ipam.mode=kubernetes \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set cluster.name="${cluster#kind-}" \
    --set cluster.id="${index}" \
    --kube-context "${cluster}"
  
  cilium status --wait --context "${cluster}"
  cilium clustermesh enable --context "${cluster}" --service-type NodePort
  cilium clustermesh status --context "${cluster}" --wait
done

cilium clustermesh connect --context "${CLUSTERS[1]}" --destination-context "${CLUSTERS[2]}"
cilium clustermesh status --context "${CLUSTERS[1]}" --wait
#endregion

#region METRICS-SERVER
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do
  cluster="${CLUSTERS[$index]}"
  helm install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args={--kubelet-insecure-tls} \
    --kube-context "${cluster}"
done
#endregion