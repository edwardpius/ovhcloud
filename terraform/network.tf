# Private network + subnet + gateway.
# The gateway is mandatory for a public Octavia load balancer (it carries the
# Floating IP) and is used as the nodes' single egress point.

locals {
  subnet_gateway_ip = cidrhost(var.subnet_cidr, 1)
}

resource "ovh_cloud_network_private_vrack" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-net"
  region       = var.region
}

resource "ovh_cloud_network_private_vrack_subnet" "this" {
  service_name = var.service_name
  network_id   = ovh_cloud_network_private_vrack.this.id
  name         = "${var.name_prefix}-subnet"
  region       = var.region
  cidr         = var.subnet_cidr
  gateway_ip   = local.subnet_gateway_ip
  dhcp_enabled = true

  # Leave .2-.9 free for static use; nodes and load balancers draw from this pool.
  allocation_pools = [{
    start = cidrhost(var.subnet_cidr, 10)
    end   = cidrhost(var.subnet_cidr, -2)
  }]
}

resource "ovh_cloud_gateway" "this" {
  service_name = var.service_name
  name         = "${var.name_prefix}-gw"
  region       = var.region

  external_gateway = {
    enabled = true
    model   = var.gateway_model
  }

  subnet_ids = [ovh_cloud_network_private_vrack_subnet.this.id]
}
