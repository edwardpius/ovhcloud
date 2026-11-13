output "cluster_id" {
  value = ovh_cloud_project_kube.this.id
}

output "kubeconfig" {
  description = "terraform output -raw kubeconfig > kubeconfig.yaml"
  value       = ovh_cloud_project_kube.this.kubeconfig
  sensitive   = true
}

output "egress_ip" {
  description = "Single public IP used by all nodes for outbound traffic (allow-list this on external services)."
  value       = ovh_cloud_gateway.this.current_state.external_ip
}

output "lb_flavor" {
  description = "Octavia flavor used for the Traefik load balancer."
  value       = { size = var.lb_size, name = local.lb_flavor_name, id = local.lb_flavor_id }
}

output "next_steps" {
  value = <<-EOT
    terraform output -raw kubeconfig > kubeconfig.yaml && export KUBECONFIG=$PWD/kubeconfig.yaml
    # Public IP of the load balancer (takes a few minutes after Argo CD syncs Traefik):
    kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    # Argo CD UI on https://localhost:8080 (user: admin):
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    kubectl -n argocd port-forward svc/argocd-server 8080:443
  EOT
}
