#!/usr/bin/env bash
set -euo pipefail

trap 'echo "❌ Script failed at line $LINENO: $BASH_COMMAND"' ERR

#-------------------------------
# UTILS
#-------------------------------
log() {
  echo -e "[\033[1;32mINFO\033[0m][$(date +'%H:%M:%S')] $*"
}

get_context() {
  local cluster="$1"
  echo "kind-${cluster}"
}

get_context_by_index() {
  local -n clusters_ref=$1
  local idx="$2"
  echo "kind-${clusters_ref[$idx]}"
}

get_config_path() {
  local cluster="$1"
  echo "manifests/${cluster}.yml"
}

#-------------------------------
# TOOLING
#-------------------------------
install_cilium_cli() {
  log "Checking if Cilium CLI is installed..."

  local current_version
  current_version=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

  if ! command -v cilium &>/dev/null; then
    log "Cilium CLI not found, installing version $current_version..."
    _install_cilium "$current_version"
    return
  fi

  local installed_version
  installed_version=$(cilium version 2>/dev/null | grep 'cilium-cli:' | awk '{print $2}')

  if [[ "$installed_version" != "$current_version" ]]; then
    log "Cilium CLI version mismatch (installed: $installed_version, expected: $current_version), reinstalling..."
    _install_cilium "$current_version"
  else
    log "Cilium CLI is already up-to-date (version $installed_version)"
  fi
}

_install_cilium() {
  local version=$1
  local os arch
  os=$(go env GOOS)
  arch=$(go env GOARCH)

  curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${version}/cilium-${os}-${arch}.tar.gz"{,.sha256sum}
  sha256sum --check "cilium-${os}-${arch}.tar.gz.sha256sum"
  sudo tar -C /usr/local/bin -xzvf "cilium-${os}-${arch}.tar.gz"
  rm "cilium-${os}-${arch}.tar.gz"*
  log "Cilium CLI $version installed successfully."
}

install_hubble_cli() {
  log "Checking if Hubble CLI is installed..."

  local current_version
  current_version=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)

  if ! command -v hubble &>/dev/null; then
    log "Hubble CLI not found, installing version $current_version..."
    _install_hubble "$current_version"
    return
  fi

  local installed_version
  installed_version=$(hubble version 2>/dev/null | head -n1 | awk '{print $2}' | cut -d'@' -f1)

  if [[ "$installed_version" != "$current_version" ]]; then
    log "Hubble CLI version mismatch (installed: $installed_version, expected: $current_version), reinstalling..."
    _install_hubble "$current_version"
  else
    log "Hubble CLI is already up-to-date (version $installed_version)"
  fi
}

_install_hubble() {
  local version=$1
  local os arch
  os=$(go env GOOS)
  arch=$(go env GOARCH)

  curl -L --fail --remote-name-all "https://github.com/cilium/hubble/releases/download/${version}/hubble-${os}-${arch}.tar.gz"{,.sha256sum}
  sha256sum --check "hubble-${os}-${arch}.tar.gz.sha256sum"
  sudo tar -C /usr/local/bin -xzvf "hubble-${os}-${arch}.tar.gz"
  rm "hubble-${os}-${arch}.tar.gz"*
  log "Hubble CLI $version installed successfully."
}

#-------------------------------
# CLUSTER FUNCTIONS
#-------------------------------
create_cluster() {
  local index="$1"
  local name="$2"
  local config
  config=$(get_config_path "kind-$name")

  log "Creating cluster '${name}' (ID: ${index})"

  if kind get clusters | grep -q "^${name}$"; then
    log "Cluster ${name} already exists, deleting..."
    kind delete cluster --name "${name}"
  fi

  if [[ ! -f "$config" ]]; then
    echo "❌ Missing config file: ${config}"
    exit 1
  fi

  kind create cluster --name "${name}" --config "$config"
}

install_cilium_on_cluster() {
  local index="$1"
  local name="$2"
  local context
  context=$(get_context "$name")

  log "Installing Cilium on ${context}"

  helm install cilium cilium/cilium \
    --namespace kube-system \
    --set image.pullPolicy=IfNotPresent \
    --set ipam.mode=kubernetes \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set cluster.name="${name}" \
    --set cluster.id="${index}" \
    --kube-context "${context}"

  cilium status --wait --context "${context}"
  cilium clustermesh enable --context "${context}" --service-type NodePort
  cilium clustermesh status --context "${context}" --wait
}

install_metrics_server_on_cluster() {
  local name="$1"
  local context
  context=$(get_context "$name")

  log "Installing Metrics Server on ${context}"
  helm install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args={--kubelet-insecure-tls} \
    --kube-context "${context}"
}

#-------------------------------
# MAIN ENTRYPOINT
#-------------------------------
main() {
  declare -A CLUSTERS=(
    [1]=mgmt
  )

  # Tooling
  install_cilium_cli
  install_hubble_cli

  # Cluster creation
  for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do
    create_cluster "$index" "${CLUSTERS[$index]}"
  done

  # Helm repos
  helm repo add cilium https://helm.cilium.io/ --force-update
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update

  # Cilium setup
  for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do
    install_cilium_on_cluster "$index" "${CLUSTERS[$index]}"
  done

  # ClusterMesh connection
  # cilium clustermesh connect \
  #   --context "kind-${CLUSTERS[1]}" \
  #   --destination-context "kind-${CLUSTERS[2]}"
  # cilium clustermesh status --context "kind-${CLUSTERS[1]}" --wait

  # Metrics Server setup
  for index in $(printf "%s\n" "${!CLUSTERS[@]}" | sort -n); do
    install_metrics_server_on_cluster "${CLUSTERS[$index]}"
  done

  log "✅ All clusters are ready and fully configured."
}

main "$@"
