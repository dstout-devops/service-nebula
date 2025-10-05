# cert-manager Module Main Configuration
# Following cert-manager Helm chart documentation
# https://cert-manager.io/docs/installation/helm/
# https://artifacthub.io/packages/helm/cert-manager/cert-manager

# Create namespace if requested
resource "kubernetes_namespace" "cert_manager" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      name                                 = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Install cert-manager using Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = var.create_namespace

  values = [
    yamlencode({
      # CRDs
      crds = {
        enabled = var.install_crds
      }

      # Controller
      replicaCount = var.controller.replicas
      resources    = var.controller.resources

      global = {
        leaderElection = {
          namespace = var.namespace
        }
        logLevel = var.global.log_level
      }

      # Webhook
      webhook = {
        replicaCount   = var.webhook.replicas
        timeoutSeconds = var.webhook.timeout_seconds
        resources      = var.webhook.resources
      }

      # CA Injector
      cainjector = {
        replicaCount = var.cainjector.replicas
        resources    = var.cainjector.resources
      }

      # Prometheus
      prometheus = {
        enabled = var.features.prometheus
      }

      # Startup API Check
      startupapicheck = {
        enabled = var.features.startupapicheck
      }

      # Feature Gates
      featureGates = var.features.feature_gates
    })
  ]

  depends_on = [kubernetes_namespace.cert_manager]
}
