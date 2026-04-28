# k3s Cluster Deployment

Deploys the k3s cluster across 5 nodes, installs NVIDIA drivers, labels nodes, and bootstraps Flux GitOps.

## Prerequisites

- Phase 1–3 complete (VMs provisioned, Tailscale configured, base services running)
- PostgreSQL 16 running on db VM (`192.168.30.16`)
- NFS shares exported from nas (`192.168.30.15`)
- `vault_flux_github_deploy_key` in SOPS vault (SSH deploy key for jellybuntu-helm)

## Deploy

```bash
./bin/runtime/ansible-run.sh playbooks/infrastructure/k3s-cluster.yml
```

## What the Playbook Does

1. **GPU passthrough** — configures VFIO/IOMMU on k8s-gpu for GTX 1080
2. **Control plane** — installs k3s on k8s-control (`.40`), generates join token
3. **Workers** — joins k8s-gpu (`.41`), k8s-media (`.42`), k8s-net (`.43`), k8s-ops (`.44`)
4. **NVIDIA drivers** — installs drivers + container toolkit on k8s-gpu
5. **Node labels** — applies `jellybuntu.io/role` labels (see table below)
6. **Flux bootstrap** — installs Flux, points to `jellybuntu-helm` repo (`main` branch, SSH)

## Node Labels

| Node | IP | `jellybuntu.io/role` | Workloads |
|---|---|---|---|
| k8s-control | .40 | _(control plane, no workloads)_ | — |
| k8s-gpu | .41 | `gpu` | Jellyfin, Tdarr |
| k8s-media | .42 | `media` | *arr stack, download clients |
| k8s-net | .43 | `net` | Traefik ingress |
| k8s-ops | .44 | `ops` | Matrix, TeamSpeak |

## Verify

```bash
# Nodes ready
kubectl get nodes -o wide

# All system pods running
kubectl get pods -A

# Flux kustomizations reconciled
flux get kustomizations -A

# HelmReleases deployed
flux get helmreleases -A
```

## Notes

- Playbook is idempotent — safe to re-run.
- Flux automatically deploys all HelmReleases after bootstrap completes. Allow ~5 min for full reconciliation.
- MetalLB advertises VIP pool `192.168.30.200/29` via L2 mode on k8s-net.

## See Also

- [Flux GitOps Workflow](flux-gitops.md)
- [k3s Namespace Reference](../reference/k3s-namespaces.md)
- [jellybuntu-helm Repo Layout](../reference/helm-repo-layout.md)
