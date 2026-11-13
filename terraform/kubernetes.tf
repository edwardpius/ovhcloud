resource "ovh_cloud_project_kube" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-mks"
  region       = var.region
  plan         = var.kube_plan
  version      = var.kube_version

  private_network_id = ovh_cloud_network_private_vrack.this.id
  nodes_subnet_id    = ovh_cloud_network_private_vrack_subnet.this.id

  # Route node egress through the private network's gateway (single, stable egress IP).
  private_network_configuration {
    default_vrack_gateway              = ""
    private_network_routing_as_default = true
  }

  update_policy = "MINIMAL_DOWNTIME"

  depends_on = [ovh_cloud_gateway.this]
}

locals {
  # One pool when no zones are given, otherwise one pool per zone.
  node_pools = length(var.availability_zones) == 0 ? { "default" = null } : {
    for z in var.availability_zones : z => z
  }
}

resource "ovh_cloud_project_kube_nodepool" "this" {
  for_each = local.node_pools

  service_name = var.service_name
  kube_id      = ovh_cloud_project_kube.this.id
  name         = each.value == null ? "${var.name_prefix}-pool" : "${var.name_prefix}-${each.key}" # no "_" allowed
  flavor_name  = var.node_flavor

  desired_nodes = var.node_count
  min_nodes     = var.node_count
  max_nodes     = var.node_max_count
  autoscale     = var.node_max_count > var.node_count

  availability_zones = each.value == null ? null : [each.value]
}
