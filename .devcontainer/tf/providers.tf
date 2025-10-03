terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
    }
    kind = {
      source  = "tehcyx/kind"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    local = {
      source  = "hashicorp/local"
    }
    null = {
      source  = "hashicorp/null"
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

provider "kubernetes" {
  alias          = "mgmt"
  config_path    = var.global_config.kubeconfig_path
  config_context = "kind-mgmt"
}
provider "local" {}

provider "null" {}