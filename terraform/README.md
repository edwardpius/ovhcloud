# OVHcloud Kubernetes cluster + Argo CD bootstrap

Costs: see [`../COST-ESTIMATE.md`](../COST-ESTIMATE.md). The defaults give about €124/month.

## What gets created

```
Internet ──► Floating IP ──► Octavia LB (S/M/L/XL) ──► Traefik (ingress) ──► your apps
                                    │
             private network + subnet + Gateway ◄── node egress (single IP)
                                    │
                 Managed Kubernetes cluster (Free or Standard) + node pool(s)
                                    │
                 Argo CD ──► "traefik" app  +  "root" app ──► gitops/apps/*.yaml
```

| File | Contents |
|---|---|
| `network.tf` | vRack private network, subnet, Gateway |
| `kubernetes.tf` | Managed Kubernetes cluster and node pool(s), with optional per-zone pools |
| `argocd.tf` | Argo CD (Helm), the Traefik Application with the load-balancer flavor annotation, and the root app-of-apps |
| `../gitops/` | Example app-of-apps entry and a `whoami` workload behind Traefik |

Terraform's job ends at the bootstrap. Argo CD manages apps from Git, and Kubernetes creates the load balancer itself.

## Prerequisites

1. A Public Cloud project with **vRack enabled** (Console → Public Cloud → Private Network).
2. OVHcloud API credentials, exported in your shell:
   ```sh
   export OVH_ENDPOINT=ovh-eu
   export OVH_CLIENT_ID=...  OVH_CLIENT_SECRET=...       # OAuth2 service account
   # or: OVH_APPLICATION_KEY / OVH_APPLICATION_SECRET / OVH_CONSUMER_KEY
   ```
3. Push this folder to a Git repo. Then set `repoURL` in `gitops/apps/demo.yaml` and `gitops_repo_url` in `terraform.tfvars` to that repo.
   - If the repo is private, add credentials in Argo CD (`argocd repo add ...`, or a repository Secret).

## Deploy

```sh
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit it
terraform init
terraform apply                                 # ~10–15 min (cluster + nodes)
terraform output next_steps
```

Then:

```sh
terraform output -raw kubeconfig > kubeconfig.yaml && export KUBECONFIG=$PWD/kubeconfig.yaml
kubectl -n argocd get applications                 # traefik, root, demo → Synced/Healthy
LB_IP=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$LB_IP/                                # whoami response
```

## Adding an application

Add an Argo CD `Application` manifest under `gitops/apps/`, pointing at your manifests, Helm chart or Kustomize folder. Commit and push, and Argo CD deploys it. Expose it with an `Ingress` (`ingressClassName: traefik`) and a `ClusterIP` Service. Don't use `type: LoadBalancer`, because every such Service creates another paid load balancer and Floating IP.

## Switching to production (Standard plan)

Set `kube_plan = "standard"`, `node_flavor = "b3-16"`, `lb_size = "M"` and `gateway_model = "M"`.

- **Changing `kube_plan` recreates the cluster.** Choose the plan before going live.
- **The load-balancer annotation differs by plan.** The Free plan selects the flavor by name; the Standard plan needs the flavor UUID. `argocd.tf` looks up the UUID and picks the right annotation automatically.
- **For 3-zone resilience**, use a 3-zone region (e.g. `EU-WEST-PAR`) and set `availability_zones`.

## Teardown: avoid orphaned billing

The Octavia load balancer and its Floating IP are created by Kubernetes, not Terraform. Delete them first, otherwise they keep billing and the network deletion fails:

```sh
kubectl -n argocd delete application root traefik --wait   # finalizers prune the Traefik Service → LB deleted
kubectl -n traefik get svc                                  # confirm it is gone
terraform destroy
```

Afterwards, check Console → Public Cloud → Load Balancer and Floating IPs for leftovers.

## Suggested next steps

- **TLS:** add cert-manager plus a Let's Encrypt `ClusterIssuer` through `gitops/apps/`, or use Traefik's built-in ACME support.
- **Argo CD UI:** expose it through a Traefik Ingress with TLS, and enable single sign-on.
- **Remote Terraform state:** use OVHcloud Object Storage via the S3 backend.
