terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kind = {
      source = "tehcyx/kind"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    tls = {
      source = "hashicorp/tls"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

provider "helm" {
  alias = "mgmt"
  kubernetes = {
    config_path    = var.global_config.kubeconfig_path
    config_context = "kind-mgmt"
  }
}

provider "kind" {}

provider "kubectl" {
  alias            = "mgmt"
  config_path      = var.global_config.kubeconfig_path
  config_context   = "kind-mgmt"
  load_config_file = true
}

provider "kubernetes" {
  alias          = "mgmt"
  config_path    = var.global_config.kubeconfig_path
  config_context = "kind-mgmt"
}

provider "local" {}

provider "null" {}

provider "vault" {
  # Vault provider configuration for PKI configuration
  # Vault is deployed with TLS, so we use HTTPS
  address          = "https://localhost:8200"
  skip_child_token = true
  skip_tls_verify  = true # Using self-signed certs in dev

  # Authentication via environment variables:
  # - VAULT_TOKEN (from vault-unseal-keys secret)
  # Requires port-forward: kubectl port-forward -n vault svc/vault 8200:8200
}