variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "cluster_id" {
  description = "Unique cluster ID for Cilium cluster mesh (1-255)"
  type        = number

  validation {
    condition     = var.cluster_id >= 1 && var.cluster_id <= 255
    error_message = "Cluster ID must be between 1 and 255 for Cilium cluster mesh."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for Cilium"
  type        = string
  default     = "kube-system"
}

variable "enable_hubble" {
  description = "Enable Hubble observability"
  type        = bool
  default     = true
}

variable "enable_hubble_ui" {
  description = "Enable Hubble UI"
  type        = bool
  default     = true
}

variable "ipam_mode" {
  description = "IPAM mode for Cilium"
  type        = string
  default     = "kubernetes"
}

variable "cilium_version" {
  description = "Cilium chart version"
  type        = string
  default     = "stable"
}

variable "image_pull_policy" {
  description = "Image pull policy for Cilium containers"
  type        = string
  default     = "IfNotPresent"
}

variable "hubble_ui_version" {
  description = "Hubble UI version tag"
  type        = string
  default     = "v0.13.1"
}

variable "additional_values" {
  description = "Additional Helm values to merge"
  type        = map(string)
  default     = {}
}
