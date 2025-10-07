terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}