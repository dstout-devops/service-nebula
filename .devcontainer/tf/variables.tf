# Root-level variables for cluster configuration

variable "mgmt_worker_count" {
  description = "Number of worker nodes for the management cluster"
  type        = number
  default     = 3
}

variable "mgmt_enable_ingress" {
  description = "Enable ingress for the management cluster"
  type        = bool
  default     = false
}

# Add more variables here as you add additional clusters
