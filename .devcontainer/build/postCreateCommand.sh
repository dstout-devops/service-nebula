#!/bin/bash
set -e

go install sigs.k8s.io/kind@latest
go install sigs.k8s.io/cloud-provider-kind@latest
go install github.com/derailed/k9s@latest

# deploy services
cd .devcontainer/kind && bash collapse-gravity.sh