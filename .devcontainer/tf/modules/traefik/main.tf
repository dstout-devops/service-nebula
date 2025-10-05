# =============================================================================
# Traefik Ingress Controller Module
# Deploys and configures Traefik as the ingress controller for Kubernetes
# =============================================================================

# Create namespace for Traefik
resource "kubernetes_namespace" "traefik" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "traefik"
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "ingress-controller"
    }
  }
}

# Deploy Traefik using Helm
resource "helm_release" "traefik" {
  name       = var.release_name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 600

  # Wait for all resources to be ready
  wait          = true
  wait_for_jobs = true

  # Core Traefik configuration
  values = [
    yamlencode({
      # Global settings
      globalArguments = var.global_arguments

      # Additional arguments
      additionalArguments = var.additional_arguments

      # Deployment configuration
      deployment = {
        enabled  = var.deployment.enabled
        kind     = var.deployment.kind
        replicas = var.deployment.replicas

        podAnnotations = var.deployment.pod_annotations
        podLabels      = var.deployment.pod_labels

        # Additional containers
        additionalContainers = var.deployment.additional_containers
      }

      # Service configuration
      service = {
        enabled = var.service.enabled
        type    = var.service.type

        annotations = var.service.annotations
        labels      = var.service.labels

        spec = var.service.spec
      }

      # Ports configuration
      ports = var.ports

      # IngressRoute
      ingressRoute = var.ingress_route

      # Providers
      providers = {
        kubernetesCRD = {
          enabled            = var.traefik_providers.kubernetes_crd.enabled
          allowCrossNamespace = var.traefik_providers.kubernetes_crd.allow_cross_namespace
          allowExternalNameServices = var.traefik_providers.kubernetes_crd.allow_external_name_services
          namespaces         = var.traefik_providers.kubernetes_crd.namespaces
        }

        kubernetesIngress = {
          enabled                   = var.traefik_providers.kubernetes_ingress.enabled
          allowExternalNameServices = var.traefik_providers.kubernetes_ingress.allow_external_name_services
          namespaces                = var.traefik_providers.kubernetes_ingress.namespaces
          publishedService = {
            enabled = var.traefik_providers.kubernetes_ingress.published_service_enabled
          }
        }
      }

      # RBAC
      rbac = {
        enabled = var.rbac.enabled
        namespaced = var.rbac.namespaced
      }

      # Service Account
      serviceAccount = {
        create = true
        name   = var.service_account.name
      }

      # Resources
      resources = var.resources

      # Security Context
      securityContext   = var.security_context
      podSecurityContext = var.pod_security_context

      # Node Selection
      nodeSelector = var.node_selector
      tolerations  = var.tolerations
      affinity     = var.affinity

      # Persistence (for certificates, etc.)
      persistence = var.persistence

      # Logs
      logs = var.logs

      # Metrics
      metrics = var.metrics

      # Tracing
      tracing = var.tracing

      # Dashboard
      dashboard = var.dashboard

      # Health checks
      readinessProbe  = var.readiness_probe
      livenessProbe   = var.liveness_probe
    })
  ]

  depends_on = [
    kubernetes_namespace.traefik
  ]
}

# Optional: Create default middleware configurations
module "middleware" {
  source = "./modules/middleware"
  count  = var.create_default_middleware ? 1 : 0

  namespace = var.namespace
  
  # Middleware configurations by type
  headers_middlewares         = try(var.default_middlewares.headers, {})
  rate_limit_middlewares      = try(var.default_middlewares.rate_limit, {})
  retry_middlewares           = try(var.default_middlewares.retry, {})
  circuit_breaker_middlewares = try(var.default_middlewares.circuit_breaker, {})
  basic_auth_middlewares      = try(var.default_middlewares.basic_auth, {})
  forward_auth_middlewares    = try(var.default_middlewares.forward_auth, {})
  ip_whitelist_middlewares    = try(var.default_middlewares.ip_whitelist, {})
  redirect_middlewares        = try(var.default_middlewares.redirect, {})
  strip_prefix_middlewares    = try(var.default_middlewares.strip_prefix, {})
  compress_middlewares        = try(var.default_middlewares.compress, {})
  chain_middlewares           = try(var.default_middlewares.chain, {})

  depends_on = [
    helm_release.traefik
  ]
}

# Optional: Create TLS configurations
module "tls" {
  source = "./modules/tls"
  count  = var.tls_config.enabled ? 1 : 0

  namespace = var.namespace
  
  # TLS configurations
  tls_stores          = try(var.tls_config.stores, {})
  tls_options         = try(var.tls_config.options, {})
  certificates        = try(var.tls_config.certificates, {})
  certificate_secrets = try(var.tls_config.certificate_secrets, {})
  servers_transports  = try(var.tls_config.servers_transports, {})

  depends_on = [
    helm_release.traefik
  ]
}

# Optional: Create IngressRoute configurations
module "ingress_routes" {
  source = "./modules/ingress-routes"
  count  = var.create_ingress_routes ? 1 : 0

  namespace = var.namespace
  
  # IngressRoute configurations
  http_routes  = var.ingress_routes.http
  https_routes = var.ingress_routes.https
  tcp_routes   = var.ingress_routes.tcp
  udp_routes   = var.ingress_routes.udp

  depends_on = [
    helm_release.traefik,
    module.middleware,
    module.tls
  ]
}
