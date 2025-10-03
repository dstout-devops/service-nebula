variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
}

variable "metrics_server_version" {
  description = "Version of the metrics-server Helm chart"
  type        = string
  default     = "3.13.0"
}

variable "namespace" {
  description = "Kubernetes namespace to install metrics-server"
  type        = string
  default     = "kube-system"
}

variable "enable_kubelet_insecure_tls" {
  description = "Enable insecure TLS for kubelet (required for kind clusters)"
  type        = bool
  default     = true
}

variable "image_pull_policy" {
  description = "Image pull policy for metrics-server"
  type        = string
  default     = "IfNotPresent"
}

variable "replicas" {
  description = "Number of metrics-server replicas"
  type        = number
  default     = 1
}