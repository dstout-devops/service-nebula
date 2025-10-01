#!/usr/bin/env bash
set -e

sed -i 's/plugins=(git)/plugins=(docker kubectl kubectx)/' ~/.zshrc
tofu -install-autocomplete

go install sigs.k8s.io/kind@latest
go install sigs.k8s.io/cloud-provider-kind@latest

# deploy services
cd .devcontainer/kind && bash collapse-gravity.sh