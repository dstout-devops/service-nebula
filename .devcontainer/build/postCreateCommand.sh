#!/usr/bin/env bash
set -e

echo "Setting up shell environment..."
sed -i 's/plugins=(git)/plugins=(docker kubectl kubectx)/' ~/.zshrc
tofu -install-autocomplete

echo "Installing kind and cloud-provider-kind..."
go install sigs.k8s.io/kind@latest
go install sigs.k8s.io/cloud-provider-kind@latest

# Create kind cluster using OpenTofu
echo "Creating kind cluster 'mgmt' with OpenTofu..."
cd .devcontainer/tf

# Use /tmp for ephemeral state - will be cleaned on container rebuild
export TF_DATA_DIR="/tmp/.terraform"
export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugins"
mkdir -p "$TF_DATA_DIR" "$TF_PLUGIN_CACHE_DIR"


# Initialize and apply
tofu init
tofu apply -auto-approve

# Set kubeconfig context to the new cluster
kubectl config use-context kind-mgmt

echo "Kind cluster 'mgmt' created successfully!"
echo "Cluster info:"
kubectl cluster-info