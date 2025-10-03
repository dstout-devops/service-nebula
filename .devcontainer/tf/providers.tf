terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
    }
    kind = {
      source  = "tehcyx/kind"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    null = {
      source  = "hashicorp/null"
    }
  }
}

provider "helm" {
  alias = "mgmt"
  kubernetes = {
    config_path    = var.global_config.kubeconfig_path
    config_context = "kind-mgmt"
  }
}
provider "kind" {}
provider "kubernetes" {}
provider "null" {}