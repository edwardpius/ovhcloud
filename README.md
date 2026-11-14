# OVHcloud Kubernetes with Terraform + Argo CD

Infrastructure-as-code for a **Managed Kubernetes cluster on OVHcloud**, exposed through an **Octavia load balancer**, with applications deployed by **Argo CD** using GitOps.

The checked-in configuration (`terraform/terraform.tfvars.example`) targets a cost-optimised development cluster in **US West** (`US-WEST-OR-1`, Hillsboro, Oregon), at about **$79/month**.

```
                 Internet
                    │
            Floating IP (public)
                    │
       Octavia Load Balancer (size S)
                    │
   ┌────────────────┼──── Kubernetes cluster (Free plan) ───────────────┐
   │                ▼                                                  │
   │     Traefik (ingress controller) ──► your apps (Ingress rules)    │
   │                                                                   │
   │     Argo CD ──► watches this repo (gitops/apps) ──► deploys apps  │
   │                                                                   │
   │     2–3 worker nodes (d2-8) on a private network                  │
   └────────────────┬──────────────────────────────────────────────────┘
                    │ outbound traffic
          Gateway (size S) ──► Internet (single egress IP)
```

## How it works

1. **Terraform** creates the infrastructure:
   - private network, subnet and Gateway
   - the Kubernetes cluster and its node pool
   - **Argo CD** itself
   - two Argo CD apps: **Traefik**, and a **root** app that points back at this repo
2. **Argo CD** installs Traefik. Traefik's `LoadBalancer` Service makes OVHcloud create the **Octavia load balancer** and its Floating IP.
3. From then on, **Git is the source of truth.** Any Argo CD `Application` placed in `gitops/apps/` is deployed automatically, and changes pushed to `main` are synced.

Terraform's job ends at the bootstrap. App deployments go through Git, not `terraform apply`.

## Repository layout

```
.
├── README.md                    ← you are here
├── COST-ESTIMATE.md             ← researched pricing (EU + US), scenarios, cost tips
├── terraform/
│   ├── versions.tf              ← Terraform + provider versions (ovh, helm)
│   ├── providers.tf             ← OVHcloud provider; Helm provider wired to the new cluster
│   ├── variables.tf             ← all inputs with defaults and descriptions
│   ├── network.tf               ← private network (vRack), subnet, Gateway
│   ├── kubernetes.tf            ← Kubernetes cluster + node pool(s), autoscaling, zones
│   ├── argocd.tf                ← Argo CD, Traefik app (LB flavor annotation), root app-of-apps
│   ├── outputs.tf               ← kubeconfig, egress IP, LB flavor, next-step commands
│   ├── terraform.tfvars.example ← US West dev config (+ EU alternatives, commented)
│   └── README.md                ← Terraform-specific details
└── gitops/
    ├── apps/demo.yaml           ← Argo CD Application (picked up by the root app)
    └── workloads/demo/demo.yaml ← example "whoami" app: Deployment, Service, Ingress
```

## Cost

| Component | US West dev configuration | ≈ $/month |
|---|---|---|
| Kubernetes control plane | Free plan | 0 |
| Worker nodes | 2 × d2-8 (4 vCPU / 8 GB), autoscale to 3 | 67.31 |
| Load balancer + Floating IP | Octavia size S (200 Mbit/s) | 9.27 |
| Gateway | Size S | 2.34 |
| **Total** | | **≈ 79** |

- **If the third node scales in**, the total is about $112.
- **Persistent volumes** cost $0.096 per GB-month.
- **For EU pricing and a production (Standard plan) setup**, see [`COST-ESTIMATE.md`](COST-ESTIMATE.md).

## Prerequisites

| Requirement | Notes |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.6 | Tested with 1.17 |
| `kubectl` | To inspect the cluster and reach the Argo CD UI |
| OVHcloud **US** account | [us.ovhcloud.com](https://us.ovhcloud.com). EU and US are separate accounts. |
| A Public Cloud project | Its 32-character ID becomes `service_name` |
| vRack enabled on the project | Public Cloud → Network → Private Network (free) |
| OVHcloud US API credentials | See below |

### Getting API credentials

1. Open <https://us.ovhcloud.com/auth/api/createToken?GET=/*&POST=/*&PUT=/*&DELETE=/*> and log in with your US account.
2. Name the application (e.g. `terraform-ovhcloud`), pick a validity period, and click **Create keys**.
3. Copy the **Application Key**, **Application Secret** and **Consumer Key**. The secret and consumer key are shown only once.
4. Store them **outside this repo** in `~/.ovh.conf`:

   ```ini
   [default]
   endpoint=ovh-us

   [ovh-us]
   application_key=...
   application_secret=...
   consumer_key=...
   ```

   ```sh
   chmod 600 ~/.ovh.conf
   ```

   Or export them as environment variables instead: `OVH_ENDPOINT=ovh-us`, `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET` and `OVH_CONSUMER_KEY`.

> **Never commit credentials. This repository is public.** `terraform.tfvars`, state files and kubeconfigs are already excluded by `.gitignore`.

## Quick start

```sh
git clone https://github.com/edwardpius/ovhcloud.git
cd ovhcloud/terraform

cp terraform.tfvars.example terraform.tfvars
#  → set service_name to your Public Cloud project ID

terraform init
terraform plan        # verify credentials and review what will be created
terraform apply       # ~10–15 minutes
```

### Connect to the cluster

```sh
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$PWD/kubeconfig.yaml

kubectl get nodes
kubectl -n argocd get applications        # traefik, root, demo → Synced / Healthy
```

### Test the load balancer

The public IP appears a few minutes after Argo CD syncs Traefik:

```sh
LB_IP=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$LB_IP/       # response from the demo "whoami" app
```

### Open the Argo CD UI

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Browse to <https://localhost:8080> and log in as `admin` with the password printed above. The UI is intentionally not public, so it doesn't need a second paid load balancer.

## Deploying your own application

1. **Add the Kubernetes manifests** under `gitops/workloads/<app>/`. You can also point the Application at a Helm chart or a Kustomize folder instead.
2. **Add an Argo CD Application** in `gitops/apps/<app>.yaml`, using `gitops/apps/demo.yaml` as the template.
3. **Expose it** with a `ClusterIP` Service plus an `Ingress` with `ingressClassName: traefik`, and add a `host:` once DNS points at the load-balancer IP.
4. **Commit and push to `main`.** Argo CD deploys it within about 3 minutes, or immediately if you click *Refresh* in the UI.

> Don't create Services of `type: LoadBalancer` for apps. Each one provisions another billed load balancer and Floating IP. Route everything through Traefik.

## Configuration

All variables are in [`terraform/variables.tf`](terraform/variables.tf). The most important:

| Variable | Dev value (tfvars) | Description |
|---|---|---|
| `service_name` | *(required)* | Public Cloud project ID |
| `ovh_endpoint` | `ovh-us` | API endpoint: `ovh-us`, `ovh-eu` or `ovh-ca` |
| `region` | `US-WEST-OR-1` | Region; US regions are single-zone and Free plan only |
| `kube_plan` | `free` | `free` or `standard`. **Changing it recreates the cluster.** |
| `node_flavor` | `d2-8` | Worker flavor. `b3-8`/`b3-16` give dedicated CPU. |
| `node_count` / `node_max_count` | `2` / `3` | Minimum and maximum nodes; autoscaling turns on when max > min |
| `availability_zones` | `[]` | 3-zone regions only (e.g. `EU-WEST-PAR`): one pool per zone |
| `lb_size` | `S` | Octavia size `S` / `M` / `L` / `XL` |
| `gateway_model` | `S` | Gateway size; carries all node egress |
| `gitops_repo_url` | this repo | Repo Argo CD watches |
| `gitops_apps_path` | `gitops/apps` | Folder of Application manifests |

`terraform.tfvars.example` also contains commented-out **EU** and **production (Standard plan, 3 availability zones)** setups. The Standard plan isn't available in OVHcloud US regions.

## Teardown

The load balancer and Floating IP are created by Kubernetes, not Terraform. **Remove them first**, otherwise they keep billing and the network can't be deleted:

```sh
kubectl -n argocd delete application root traefik --wait
kubectl -n traefik get svc            # should be empty / namespace gone
cd terraform && terraform destroy
```

Then check the Control Panel (Public Cloud → Load Balancer, Floating IPs) for leftovers.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `invalid signature` / `This credential does not exist` / 403 | Wrong or unvalidated keys, or endpoint not `ovh-us` |
| Cluster creation fails on the network | vRack not enabled on the project |
| Traefik Service stuck in `<pending>` | Load balancer still provisioning (wait 2–5 min); check `kubectl -n traefik describe svc traefik` |
| `root` / `demo` apps show `ComparisonError` | Argo CD can't read the repo (URL wrong, or repo made private) |
| Pods `Pending` | Not enough capacity; raise `node_max_count` or use a larger `node_flavor` |

## Roadmap

- **TLS:** cert-manager with a Let's Encrypt `ClusterIssuer`, or Traefik's built-in ACME support.
- **Argo CD UI:** expose it through Traefik with TLS and single sign-on.
- **Terraform state:** move it to a remote backend, e.g. OVHcloud Object Storage via the S3 backend.
- **Secrets:** add Sealed Secrets or External Secrets for app secrets, since this repo is public.
