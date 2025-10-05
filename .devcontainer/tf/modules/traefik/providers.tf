# =============================================================================
# Traefik Module Provider Requirements
# Version constraints are defined in the root configuration
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
