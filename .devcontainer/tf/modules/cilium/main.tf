# Pre-pull Cilium images and load them into kind cluster
# This solves the chicken-and-egg problem: CNI needs network, but network needs CNI
resource "null_resource" "prepull_images" {
  triggers = {
    cluster_name   = var.cluster_name
    cilium_version = var.cilium_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "🔄 Extracting images from Cilium Helm chart v${var.cilium_version}..."
      
      # Add Cilium Helm repo if not present
      helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
      helm repo update cilium
      
      # Template the chart with our settings to extract exact images
      IMAGES=$(helm template cilium cilium/cilium \
        --version ${var.cilium_version} \
        --set hubble.relay.enabled=${var.enable_hubble} \
        --set hubble.ui.enabled=${var.enable_hubble_ui} \
        | grep -E "image:|Image:" \
        | grep -v "imagePullPolicy" \
        | awk -F': ' '{print $2}' \
        | tr -d '"' \
        | sort -u \
        | grep -v "^$")
      
      echo "📥 Images to pre-load:"
      echo "$IMAGES" | sed 's/^/  - /'
      
      # Pull and load each image
      echo ""
      echo "🔄 Pulling images..."
      while IFS= read -r IMAGE; do
        if [ -n "$IMAGE" ]; then
          echo "  → $IMAGE"
          docker pull "$IMAGE" || echo "⚠️  Failed to pull $IMAGE"
        fi
      done <<< "$IMAGES"
      
      echo ""
      echo "📦 Loading images into Kind cluster '${var.cluster_name}'..."
      while IFS= read -r IMAGE; do
        if [ -n "$IMAGE" ]; then
          # Remove digest if present for kind load
          IMAGE_NAME=$(echo "$IMAGE" | cut -d'@' -f1)
          echo "  → $IMAGE_NAME"
          kind load docker-image "$IMAGE_NAME" --name ${var.cluster_name} || echo "⚠️  Failed to load"
        fi
      done <<< "$IMAGES"
      
      echo ""
      echo "✅ All Cilium images loaded into cluster!"
    EOT
  }
}

# Install Cilium using Helm provider
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = var.namespace

  set = [
    {
      name  = "image.pullPolicy"
      value = "IfNotPresent" # Use pre-loaded images
    },
    {
      name  = "operator.image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "envoy.image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "hubble.relay.image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "hubble.ui.frontend.image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "hubble.ui.backend.image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "ipam.mode"
      value = var.ipam_mode
    },
    {
      name  = "cluster.name"
      value = var.cluster_name
    },
    {
      name  = "cluster.id"
      value = var.cluster_id
    },
    {
      name  = "hubble.relay.enabled"
      value = var.enable_hubble
    },
    {
      name  = "hubble.ui.enabled"
      value = var.enable_hubble_ui
    }
  ]

  depends_on = [null_resource.prepull_images]
}
