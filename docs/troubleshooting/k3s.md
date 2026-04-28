# k3s Troubleshooting

Common issues and diagnostics for the k3s cluster (Flux GitOps, Helm, storage, GPU, networking).

> **IMPORTANT**: Most services run on k3s. Use `kubectl` and `flux` commands. Read-only diagnostics always permitted without asking — state-changing fixes go through Ansible/Flux.

## General Diagnostics

```bash
# Node health
kubectl get nodes -o wide
kubectl describe node <node>
kubectl top nodes

# Pod status
kubectl get pods -A
kubectl get pods -A | grep -v "Running\|Completed"

# Recent events (last 30)
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# Resource usage
kubectl top pods -A
```

## Flux Issues

### HelmRelease Stuck

```bash
kubectl get helmreleases -A
kubectl describe helmrelease <name> -n <namespace>
flux reconcile helmrelease <name> -n <namespace>
flux reconcile kustomization <name> -n flux-system
```

### Git Source Not Syncing

```bash
flux get sources git -A
flux reconcile source git flux-system -n flux-system
```

### SOPS Decryption Failure

```bash
kubectl get secret sops-age -n flux-system
# If missing: re-add age private key to the cluster secret
```

### Kustomization Failing

```bash
flux get kustomizations -A
kubectl describe kustomization <name> -n flux-system
# Check status.conditions for error message
```

## Storage Issues

### PVC Pending

```bash
kubectl get pvc -A
kubectl describe pvc <name> -n <namespace>
kubectl get pods -n nfs-system  # check NFS provisioner is running
```

### NFS Mount Failures

```bash
# Debug from inside the cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# apk add nfs-utils && showmount -e 192.168.30.15
```

### Transcode Cache Missing on k8s-gpu

Dirs `/mnt/transcode-cache/jellyfin` and `/mnt/transcode-cache/tdarr` must exist on k8s-gpu.

If missing: propose fix in the k3s-cluster Ansible playbook. Do not create manually (IaC rule).

## GPU Issues (k8s-gpu)

### GPU Not Available

```bash
kubectl describe node k8s-gpu | grep -A5 "Capacity"
# Should show: nvidia.com/gpu: 2 (time-sliced)

kubectl get pods -n kube-system | grep nvidia
kubectl logs -n kube-system daemonset/nvidia-device-plugin

kubectl exec -it -n gpu deployment/jellyfin -- nvidia-smi
```

### GPU Pod Not Scheduling

Verify the node taint `nvidia.com/gpu:NoSchedule` exists on k8s-gpu and that the pod spec includes a matching toleration.

## Networking / Ingress Issues

### Service Not Reachable Externally

```bash
# Traefik LoadBalancer should show 192.168.30.200
kubectl get svc -A | grep LoadBalancer

kubectl get pods -n traefik-system
kubectl logs -n traefik-system deployment/traefik

kubectl get ingressroutes -A
```

### TLS Cert Issues

```bash
kubectl exec -it -n traefik-system deployment/traefik -- ls /data/
# If acme.json is corrupt: delete the Traefik PVC — it re-issues automatically
```

### DNS Not Resolving *.elysium.industries

- AdGuard Home DNS rewrites on NAS must point to MetalLB VIP `192.168.30.200`
- CoreDNS custom config forwards `elysium.industries` to `192.168.30.15:53`

## Media Namespace Issues

### DB Connection Failures (Sonarr / Radarr / etc.)

```bash
# Test DB connectivity from inside the cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# apk add postgresql-client && psql -h 192.168.30.16 -U sonarr -d sonarr_main

# View XML config generation (init container logs)
kubectl logs -n media <pod> -c init-config
```

### qBittorrent VPN Not Connecting

```bash
kubectl logs -n media deployment/qbittorrent -c gluetun
kubectl logs -n media deployment/qbittorrent -c port-sync
```

## Useful One-liners

```bash
# All non-running pods
kubectl get pods -A | grep -v "Running\|Completed"

# All HelmRelease failures
kubectl get helmreleases -A | grep -v "True"

# Restart a deployment
kubectl rollout restart deployment/<name> -n <namespace>

# Watch pods in a namespace
kubectl get pods -n <namespace> -w

# Namespace events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## See Also

- [Common Issues](common-issues.md)
- [Networking](networking.md)
- [NAS / NFS](nas-nfs.md)
- [Playbooks Reference](../reference/playbooks.md)
