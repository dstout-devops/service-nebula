
terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}