# OVHcloud Managed Kubernetes + Load Balancer: Cost Estimate

**Prices as of:** 12 November 2026, from the OVHcloud EU price list (`ovhcloud.com/en-ie/public-cloud/prices`)
**Currency:** EUR, excluding VAT, Linux instances, billed hourly. Monthly figures are hourly price × 730 h.

## Unit prices

| Component | What it is | €/hour | ≈ €/month |
|---|---|---|---|
| **Kubernetes control plane: Free** | 99.5% uptime target, shared etcd, single zone, up to 100 nodes | 0 | **0** |
| **Kubernetes control plane: Standard** | 99.9% uptime SLA (99.99% across 3 zones), dedicated etcd, up to 500 nodes | 0.09 | **65.70** |
| Worker node b3-8 (2 vCPU / 8 GB) | General purpose | 0.0512 | 37.38 (12- / 36-month savings plan: 31.77 / 26.16) |
| Worker node b3-16 (4 vCPU / 16 GB) | General purpose | 0.1023 | 74.68 (savings plan: 63.48 / 52.28) |
| Worker node b3-32 (8 vCPU / 32 GB) | General purpose | 0.2046 | 149.36 (savings plan: 126.95 / 104.55) |
| **Load Balancer S** (200 Mbit/s) | OpenStack Octavia | 0.0083 | **6.06** |
| **Load Balancer M** (500 Mbit/s) | Octavia | 0.0208 | **15.18** |
| **Load Balancer L** (2 Gbit/s) | Octavia | 0.0556 | **40.59** |
| Load Balancer XL | Octavia | 0.2083 | 152.06 |
| Floating IP (IPv4) | Public IP; one per public load balancer | 0.0027 | 1.97 |
| Gateway S / M / L | Internet access for the private network | 0.0028 / 0.0111 / 0.0486 | 2.04 / 8.10 / 35.48 |
| Block storage, High Speed | Persistent volumes, per GB | — | 0.087 per GB |
| Block storage, Classic | Persistent volumes, per GB | — | 0.043 per GB |

## Example monthly estimates

| | **A: Lean / dev** | **B: Production** |
|---|---|---|
| Control plane | Free: €0 | Standard: €65.70 |
| Nodes | 3 × b3-8: €112.13 | 3 × b3-16: €224.04 |
| Load balancer + Floating IP | S + IP: €8.03 | M + IP: €17.15 |
| Gateway | S: €2.04 | M: €8.10 |
| Volumes | 20 GB High Speed: €1.74 | 100 GB High Speed: €8.69 |
| **Total** | **≈ €124/month** | **≈ €324/month** (≈ €330 if each node also gets a public IP) |

The variable defaults in [`terraform/`](terraform/) match setup **A**. The active `terraform.tfvars` overrides them with the **US West dev cluster** below. To use **B** in an EU region, change these variables:

```hcl
kube_plan     = "standard"
node_flavor   = "b3-16"
lb_size       = "M"
gateway_model = "M"
```

## US West dev cluster (active configuration)

**Region:** `US-WEST-OR-1` (Hillsboro, Oregon). It has a single availability zone and only the Free plan; the Standard plan isn't offered in any US region.
**Account:** OVHcloud US (us.ovhcloud.com) is a separate account from OVHcloud EU, with endpoint `ovh-us`.
**Prices:** USD, as of 12 November 2026, hourly price × 730 h.

| Item | Price | ≈ $/month |
|---|---|---|
| Control plane, Free plan | $0 | 0 |
| 2 × d2-8 nodes (4 vCPU / 8 GB, shared CPU) | $0.0461/hour each | 67.31 |
| Load Balancer S + Floating IP | $0.0095 + $0.0032/hour | 9.27 |
| Gateway S | $0.0032/hour | 2.34 |
| Persistent volumes (High Speed) | $0.096 per GB-month | ~0 (pay only for what you claim) |
| **Total** | | **≈ $79/month** |

- **When the autoscaler adds the third node**, the total rises to about $112/month.
- **Monthly billing** (`monthly_billed = true` on the node pool) cuts a d2-8 to $25.53/month (≈ $67 total). It suits a cluster that stays up all month; the default hourly billing is cheaper if you tear the cluster down often.
- **Other US flavors for comparison:**

  | Flavor | Specs | ≈ $/month (hourly billing) |
  |---|---|---|
  | b3-8 | 2 dedicated vCPU / 8 GB | 44.17 |
  | d2-4 | 2 vCPU / 4 GB | 18.69 |

  d2-4 is too small to run Argo CD plus apps.

## Things that affect the bill

- **Your cluster config drives the load balancer cost.** When the ingress controller's `Service` is `type: LoadBalancer`, OVHcloud creates an Octavia load balancer plus a Floating IP automatically. Each extra `LoadBalancer` Service adds another load balancer and IP, so route all apps through one ingress controller (Traefik here) behind one load balancer.
- **HTTP routing runs in Traefik, behind the Octavia load balancer.** On OVHcloud Managed Kubernetes, Octavia's own HTTP routing rules and TLS termination aren't available yet, so Traefik handles routing and TLS. Ingress-nginx was retired in March 2026, so it isn't used.
- **Argo CD has no licence cost.** It runs on the worker nodes and uses about 1–2 GB of RAM. The bootstrap disables Dex (single sign-on) to save memory.
- **A Gateway is required for a public load balancer.** If none exists on the subnet, OVHcloud creates an S-size one automatically. The Terraform creates it explicitly so its size is under your control.
- **Outbound traffic is not charged in EU and Canada regions.** Asia-Pacific regions charge for it.
- **Ways to save:**
  - Savings plans cut node cost by about 15–30%.
  - Node pools also support `monthly_billed = true`.
- **Watch for orphaned resources on teardown.** The load balancer and Floating IP are created by Kubernetes, not Terraform. Delete the Traefik Service before `terraform destroy`, or they keep billing (see `terraform/README.md`).

## Sources

- [OVHcloud Public Cloud prices](https://www.ovhcloud.com/en-ie/public-cloud/prices/)
- [Kubernetes plans: Free vs Standard](https://docs.ovhcloud.com/en/guides/public-cloud/containers-orchestration/managed-kubernetes/mks-plans)
- [Expose applications using a Load Balancer (Managed Kubernetes)](https://docs.ovhcloud.com/en/guides/public-cloud/containers-orchestration/managed-kubernetes/expose-applications-using-load-balancer)
- [Standard plan launch announcement](https://corporate.ovhcloud.com/en/newsroom/news/ovhcloud-managed-kubernetes-service-standard-3az/)
- [Load Balancer product page](https://www.ovhcloud.com/en/public-cloud/load-balancer/)
