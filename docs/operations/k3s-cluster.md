# k3s Cluster

> Flux GitOps workflow and cluster operations for the jellybuntu k3s cluster.
> Cluster state is declared in
> [`jellybuntu-helm`](https://github.com/SilverDFlame/jellybuntu-helm).

## Cluster Nodes

| Node | IP | Role |
|---|---|---|
| k8s-control | 192.168.30.40 | Control plane |
| k8s-gpu | 192.168.30.41 | Worker — NVIDIA GTX 1080 |
| k8s-media | 192.168.30.42 | Worker — media workloads |
| k8s-net | 192.168.30.43 | Worker — networking |
| k8s-ops | 192.168.30.44 | Worker — observability |

Kubeconfig: `~/.kube/k3s-jellybuntu.yaml`

```bash
export KUBECONFIG=~/.kube/k3s-jellybuntu.yaml
kubectl get nodes
```

## Flux GitOps Workflow

All cluster state is declared in `jellybuntu-helm`. Pushing to `main` triggers automatic
reconciliation within 10 minutes (root sync interval). Layer reconciliation intervals are 1 hour.

```text
clusters/jellybuntu/
├── flux-system/          # Flux bootstrap — do not edit manually
├── infrastructure.yaml   # HelmRepositories + controllers (Traefik, Cilium, NFS provisioner)
├── net.yaml              # Cilium LB-IPAM pool + L2 announcement policy
├── media.yaml            # Media apps
├── gpu.yaml              # GPU workloads
└── ops.yaml              # Observability
```

Dependency chain: `infrastructure` → `media`, `gpu`, `net`, `ops`

**Manual reconcile** (force immediate sync without waiting for interval):

```bash
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization infrastructure --with-source
```

## Cluster Status

```bash
# Overview of all Flux resources
flux get all -A

# Kustomization sync status
flux get kustomizations

# HelmRelease status across all namespaces
flux get helmreleases -A

# Node status
kubectl get nodes -o wide

# All pods across all namespaces
kubectl get pods -A

# Recent Flux events/logs
flux logs --follow
```

## Inspecting a Failed Resource

```bash
# Describe a stuck HelmRelease
flux describe helmrelease <name> -n <namespace>

# Describe a pod
kubectl describe pod <pod-name> -n <namespace>

# Container logs
kubectl logs <pod-name> -n <namespace>

# Previous container logs (after CrashLoopBackOff)
kubectl logs <pod-name> -n <namespace> --previous
```

## Node Operations

```bash
# Drain a node before maintenance (evicts pods gracefully)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Prevent new pods being scheduled on a node
kubectl cordon <node-name>

# Re-enable scheduling after maintenance
kubectl uncordon <node-name>
```

**GPU node taint** — applied by the `k3s_gpu_node` role to restrict scheduling:

```bash
# Verify taint is present
kubectl describe node k8s-gpu | grep Taint

# Expected output
# Taints: nvidia.com/gpu=present:NoSchedule
```

Workloads that require GPU must include a toleration for `nvidia.com/gpu=present:NoSchedule`.

## Adding a New Service

Follow these steps when adding a new Helm-managed service to the cluster:

1. Add a `HelmRepository` source in `infrastructure/sources/` and register it in that
   directory's `kustomization.yaml`
2. Create the namespace in `infrastructure/controllers/namespaces.yaml` (namespaces must
   exist before HelmRelease objects reference them)
3. Add the `HelmRelease` in the appropriate layer directory (`media/`, `gpu/`, `ops/`, `net/`)
   and register it in that layer's `kustomization.yaml`
4. Validate locally before pushing:

```bash
kubectl kustomize clusters/jellybuntu/
kubectl kustomize clusters/jellybuntu/infrastructure/
kubectl apply --dry-run=client -f <file>
```

1. Commit and push to `main` — Flux reconciles within 10 minutes

**Namespace naming convention:** `{service}-system` (e.g., `traefik-system`, `nfs-system`). Exception: CNI-level components that integrate with k3s internals (Cilium) use `kube-system`.

**Labels:** All resources use `app.kubernetes.io/part-of: jellybuntu`

## Validate Kustomize Overlays

Run before every push to catch build errors early:

```bash
kubectl kustomize clusters/jellybuntu/
kubectl kustomize clusters/jellybuntu/infrastructure/
kubectl kustomize clusters/jellybuntu/infrastructure/sources/
kubectl kustomize clusters/jellybuntu/infrastructure/controllers/
```

## Cilium (CNI + LoadBalancer)

The cluster runs **Cilium 1.19.4** as the sole CNI with **kube-proxy replacement (kpr)**
enabled — there is no kube-proxy DaemonSet. Pod-to-pod traffic uses a VXLAN overlay on
UDP/8472. Cilium also provides LoadBalancer support, replacing MetalLB.

- **LB-IPAM pool:** `jellybuntu-pool` = `192.168.30.200/29` (`.200`–`.207`)
- **Primary VIP in use:** `192.168.30.200` (Traefik ingress)
- **L2 announcement:** `CiliumL2AnnouncementPolicy` pinned to nodes labelled
  `jellybuntu.io/role=net` (k8s-net) so ARP replies stay on the node that holds the
  Traefik backend (`externalTrafficPolicy: Local`)
- **Hubble:** enabled; default 4095-flow buffer (~6 min @ 11.4 flows/s); bump
  `hubble.eventBufferCapacity` in the HelmRelease for deeper retention

```bash
# Check Cilium agent + operator status
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get pods -n kube-system -l app=cilium-operator
cilium status      # if the cilium CLI is installed locally

# Check LB-IPAM pool + L2 announcement policy
kubectl get ciliumloadbalancerippool
kubectl get ciliuml2announcementpolicy

# See which node currently holds each L2 announcement lease
kubectl get leases -n kube-system | grep cilium-l2announce

# Check which services have assigned IPs
kubectl get svc -A | grep LoadBalancer

# Quick Hubble flow tail (in-cluster, no port-forward needed)
kubectl exec -n kube-system ds/cilium -- hubble observe --last 100
```

### Cilium firewall ports (inter-node, media VLAN 30)

See the authoritative reference in [networking.md § Firewall ports](../infrastructure/networking.md#firewall-ports).

## Flux Bootstrap (from scratch)

Only needed if Flux is not yet installed on the cluster:

```bash
flux bootstrap github \
  --owner=SilverDFlame \
  --repository=jellybuntu-helm \
  --branch=main \
  --path=clusters/jellybuntu \
  --personal
```

Alternatively, run the Ansible playbook which handles this automatically:

```bash
./bin/runtime/ansible-run.sh playbooks/infrastructure/k3s-cluster.yml
```

## Suspend / Resume Reconciliation

Pause Flux during maintenance to prevent it from reverting manual changes:

```bash
# Suspend a kustomization (e.g. during storage maintenance)
flux suspend kustomization media

# Resume when done
flux resume kustomization media
```

Suspended kustomizations are still visible in `flux get kustomizations` — status shows `Suspended`.

## NFS Storage

The `nfs-client` StorageClass is the default, backed by the NAS:

- **NFS server:** `192.168.30.15` (direct IP — bypasses Tailscale to avoid UDP saturation)
- **Export path:** `/mnt/storage/data`
- **Default StorageClass:** `nfs-client`

```bash
kubectl get storageclass
kubectl get pvc -A
```

## See Also

- [k3s Namespace Reference](k3s-namespaces.md) — service ports, URLs, in-cluster DNS
- [jellybuntu-helm Repo Layout](helm-repo.md) — chart structure, SOPS secrets, app-template notes
