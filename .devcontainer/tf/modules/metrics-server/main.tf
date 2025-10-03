# Install metrics-server using Helm provider
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = var.namespace

  # Basic configuration
  set = [
    {
      name  = "image.pullPolicy"
      value = var.image_pull_policy
    },
    {
      name  = "replicas"
      value = var.replicas
    },
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}