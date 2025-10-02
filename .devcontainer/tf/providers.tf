terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "kind" {}
provider "helm" {
  alias = "mgmt"
  kubernetes = {
    config_path    = pathexpand("~/.kube/config")
    config_context = "kind-mgmt"
  }
}