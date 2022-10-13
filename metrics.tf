// Metrics Server

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  namespace  = "kube-system"

}

// Prometheus

resource "helm_release" "prometheus" {
  name             = "prometheus-community"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "prometheus"
  create_namespace = true

  set {
    name  = "alertmanager.persistentVolume.storageClass"
    value = "ebs-sc"
  }
  set {
    name  = "server.persistentVolume.storageClass"
    value = "ebs-sc"
  }
}
