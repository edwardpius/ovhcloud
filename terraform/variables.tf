# --- OVHcloud ---------------------------------------------------------------

variable "ovh_endpoint" {
  description = "OVHcloud API endpoint (ovh-eu, ovh-ca, ovh-us)."
  type        = string
  default     = "ovh-eu"
}

variable "service_name" {
  description = "Public Cloud project ID. Its vRack must already be enabled."
  type        = string
}

variable "region" {
  description = "Public Cloud region, e.g. GRA11 (1 zone) or EU-WEST-PAR (3 zones, Standard plan only)."
  type        = string
  default     = "GRA11"
}

variable "name_prefix" {
  description = "Prefix used for all resource names (letters, digits and dashes)."
  type        = string
  default     = "app"
}

# --- Network ----------------------------------------------------------------

variable "subnet_cidr" {
  description = "Private subnet for nodes and load balancers. Must not overlap the cluster's pod/service ranges."
  type        = string
  default     = "192.168.100.0/24"
}

variable "gateway_model" {
  description = "Gateway size: S, M, L, XL, 2XL or 3XL. All node egress goes through it."
  type        = string
  default     = "S"
}

# --- Kubernetes -------------------------------------------------------------

variable "kube_plan" {
  description = "Control-plane plan: free or standard. Changing it recreates the cluster."
  type        = string
  default     = "free"

  validation {
    condition     = contains(["free", "standard"], var.kube_plan)
    error_message = "kube_plan must be \"free\" or \"standard\"."
  }
}

variable "kube_version" {
  description = "Kubernetes minor version, e.g. \"1.34\". null = latest available."
  type        = string
  default     = null
}

variable "node_flavor" {
  description = "Worker node flavor, e.g. b3-8, b3-16."
  type        = string
  default     = "b3-8"
}

variable "node_count" {
  description = "Nodes per pool (one pool per availability zone when zones are set)."
  type        = number
  default     = 3
}

variable "node_max_count" {
  description = "Upper bound for the cluster autoscaler. Equal to node_count disables autoscaling."
  type        = number
  default     = 3
}

variable "availability_zones" {
  description = "For 3-zone regions (Standard plan): one node pool is created per zone, e.g. [\"eu-west-par-a\", \"eu-west-par-b\", \"eu-west-par-c\"]. Empty for 1-zone regions."
  type        = list(string)
  default     = []
}

# --- Load balancer / ingress ------------------------------------------------

variable "lb_size" {
  description = "Octavia load balancer size for the ingress controller: S, M, L or XL."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "M", "L", "XL"], var.lb_size)
    error_message = "lb_size must be one of S, M, L, XL."
  }
}

# --- Argo CD / GitOps -------------------------------------------------------

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version."
  type        = string
  default     = "10.11.6" # Argo CD v3.5.6
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version."
  type        = string
  default     = "2.0.7"
}

variable "traefik_chart_version" {
  description = "Traefik Helm chart version (deployed by Argo CD)."
  type        = string
  default     = "42.1.3" # Traefik v3.7.16
}

variable "gitops_repo_url" {
  description = "Git repository Argo CD watches for applications (the root app-of-apps). Public repo, or add credentials in Argo CD."
  type        = string
}

variable "gitops_revision" {
  description = "Branch, tag or commit of the GitOps repo."
  type        = string
  default     = "main"
}

variable "gitops_apps_path" {
  description = "Folder in the GitOps repo containing Argo CD Application manifests."
  type        = string
  default     = "gitops/apps"
}
