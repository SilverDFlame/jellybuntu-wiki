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
├── infrastructure.yaml   # HelmRepositories + controllers (Traefik, MetalLB, NFS provisioner)
├── net.yaml              # MetalLB IP pool
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

**Namespace naming convention:** `{service}-system` (e.g., `traefik-system`, `metallb-system`)

**Labels:** All resources use `app.kubernetes.io/part-of: jellybuntu`

## Validate Kustomize Overlays

Run before every push to catch build errors early:

```bash
kubectl kustomize clusters/jellybuntu/
kubectl kustomize clusters/jellybuntu/infrastructure/
kubectl kustomize clusters/jellybuntu/infrastructure/sources/
kubectl kustomize clusters/jellybuntu/infrastructure/controllers/
```

## MetalLB

MetalLB operates in L2 mode, providing bare-metal load balancer support for `LoadBalancer`
type services.

- **VIP / service IP pool:** `192.168.30.200/29` (addresses `.200`–`.207`)
- **Primary VIP in use:** `192.168.30.200` (Traefik ingress)
- **Mode:** L2 advertisement

```bash
# Check MetalLB speaker status
kubectl get pods -n metallb-system

# Check IPAddressPool and L2Advertisement
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system

# Check which services have assigned IPs
kubectl get svc -A | grep LoadBalancer
```

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

## NFS Storage

The `nfs-client` StorageClass is the default, backed by the NAS:

- **NFS server:** `192.168.30.15` (direct IP — bypasses Tailscale to avoid UDP saturation)
- **Export path:** `/mnt/storage/data`
- **Default StorageClass:** `nfs-client`

```bash
kubectl get storageclass
kubectl get pvc -A
```
