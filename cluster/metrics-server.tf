# ------------------------------------------------------------
# Metrics Server
# ------------------------------------------------------------

resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  namespace = "kube-system"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version

  values = [
    file("${path.module}/values/metrics-server-values.yaml")
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 300

  depends_on = [
    aws_eks_node_group.default
  ]
}
