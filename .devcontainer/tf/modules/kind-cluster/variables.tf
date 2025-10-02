variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "enable_ingress" {
  description = "Enable ingress controller port mappings"
  type        = bool
  default     = false
}

variable "extra_port_mappings" {
  description = "Additional port mappings for the control plane node"
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = string
  }))
  default = []
}

variable "pod_subnet" {
  description = "CIDR range for pod network"
  type        = string
  default     = null
}

variable "service_subnet" {
  description = "CIDR range for service network"
  type        = string
  default     = null
}

variable "disable_default_cni" {
  description = "Disable the default CNI (required for custom CNI like Cilium)"
  type        = bool
  default     = false
}

variable "kube_proxy_mode" {
  description = "Kube-proxy mode (iptables or nftables)"
  type        = string
  default     = "iptables"
}

variable "mount_host_ca_certs" {
  description = "Mount host CA certificates into cluster nodes"
  type        = bool
  default     = true
}
