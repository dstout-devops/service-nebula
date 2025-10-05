# =============================================================================
# TLS Submodule Provider Requirements
# Version constraints are defined in the root configuration
# =============================================================================

terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
