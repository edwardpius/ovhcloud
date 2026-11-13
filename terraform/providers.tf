# Credentials come from the environment (never commit them):
#   OAuth2:          OVH_CLIENT_ID, OVH_CLIENT_SECRET
#   or API keys:     OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY
provider "ovh" {
  endpoint = var.ovh_endpoint
}

locals {
  kube_access = ovh_cloud_project_kube.this.kubeconfig_attributes[0]
}

provider "helm" {
  kubernetes = {
    host                   = local.kube_access.host
    client_certificate     = base64decode(local.kube_access.client_certificate)
    client_key             = base64decode(local.kube_access.client_key)
    cluster_ca_certificate = base64decode(local.kube_access.cluster_ca_certificate)
  }
}
