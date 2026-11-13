# Bootstrap: Terraform installs Argo CD once, plus two Applications.
# After that, everything in the cluster is managed by Argo CD from Git.
#
#   1. "traefik": the ingress controller. Its Service (type LoadBalancer) makes
#      OVHcloud create the Octavia load balancer + Floating IP. It lives here,
#      not in Git, because the load-balancer flavor depends on the plan/region
#      that Terraform knows.
#   2. "root": app-of-apps pointing at var.gitops_apps_path in your repo.

# --- Octavia load balancer flavor -------------------------------------------
# Free plan selects the flavor by name; Standard plan needs the flavor UUID.

data "ovh_cloud_project_loadbalancer_flavors" "this" {
  service_name = var.service_name
  region_name  = var.region
}

locals {
  lb_flavor_name = {
    S  = "small"
    M  = "medium"
    L  = "large"
    XL = "xl"
  }[var.lb_size]

  lb_flavor_id = one([
    for f in data.ovh_cloud_project_loadbalancer_flavors.this.flavors : f.id
    if f.name == local.lb_flavor_name
  ])

  lb_annotations = var.kube_plan == "free" ? {
    "loadbalancer.ovhcloud.com/flavor" = local.lb_flavor_name
    } : {
    "loadbalancer.openstack.org/flavor-id" = local.lb_flavor_id
  }
}

# --- Argo CD ----------------------------------------------------------------

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  timeout          = 600

  values = [yamlencode({
    # SSO not needed for the bootstrap; saves memory. Log in with the admin user.
    dex = { enabled = false }

    # Argo CD UI stays internal (ClusterIP) so it doesn't create a second paid
    # load balancer. Use `kubectl port-forward`, or add an Ingress via GitOps.
    server = { service = { type = "ClusterIP" } }
  })]

  # Nodes must exist before anything can be scheduled.
  depends_on = [ovh_cloud_project_kube_nodepool.this]
}

# --- Bootstrap Applications -------------------------------------------------

resource "helm_release" "argocd_bootstrap" {
  name       = "argocd-bootstrap"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applications = {
      traefik = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        source = {
          repoURL        = "https://traefik.github.io/charts"
          chart          = "traefik"
          targetRevision = var.traefik_chart_version
          helm = {
            valuesObject = {
              deployment = { replicas = 2 }
              ingressClass = {
                enabled        = true
                isDefaultClass = true
              }
              providers = {
                kubernetesIngress = { publishedService = { enabled = true } }
              }
              service = {
                type        = "LoadBalancer"
                annotations = local.lb_annotations
              }
            }
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "traefik"
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }

      root = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = var.gitops_apps_path
          directory      = { recurse = true }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
