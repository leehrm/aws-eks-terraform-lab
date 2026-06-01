# ------------------------------------------------------------
# ArgoCD Namespace
# ------------------------------------------------------------

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }

  depends_on = [
    aws_eks_node_group.default
  ]
}

# ------------------------------------------------------------
# ArgoCD Helm Release
# ------------------------------------------------------------

resource "helm_release" "argocd" {
  name      = "argocd"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 600

  depends_on = [
    kubernetes_namespace_v1.argocd,
    aws_eks_node_group.default
  ]
}

# ------------------------------------------------------------
# ArgoCD Root Application Bootstrap
# ------------------------------------------------------------

resource "helm_release" "argocd_root_apps" {
  name      = "argocd-root-apps"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [
    yamlencode({
      applications = {
        root = {
          namespace = var.argocd_namespace
          project   = "default"

          source = {
            repoURL        = var.argocd_root_app_repo_url
            targetRevision = var.argocd_root_app_target_revision
            path           = var.argocd_root_app_path
          }

          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.argocd_namespace
          }

          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }

            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 300

  depends_on = [
    helm_release.argocd
  ]
}
