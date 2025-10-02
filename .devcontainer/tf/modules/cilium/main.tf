# Pre-pull Cilium images and load them into kind cluster
resource "null_resource" "prepull_images" {
  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Pulling Cilium images locally..."
      docker pull quay.io/cilium/cilium:v${var.cilium_version}
      
      echo "Loading images into kind cluster ${var.cluster_name}..."
      kind load docker-image quay.io/cilium/cilium:v${var.cilium_version} --name ${var.cluster_name}
      
      echo "Cilium images loaded successfully into cluster!"
    EOT
  }
}

# Install Cilium using Helm provider
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  set = [
    {
      name  = "image.pullPolicy"
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
