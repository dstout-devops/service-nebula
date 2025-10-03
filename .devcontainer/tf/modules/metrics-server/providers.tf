# Provider configuration for metrics-server module

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}