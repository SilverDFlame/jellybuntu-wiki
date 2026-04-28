# Flux GitOps Workflow

All k3s workloads are managed via the `jellybuntu-helm` repo. Never `kubectl apply` directly.

**Helm repo**: https://github.com/SilverDFlame/jellybuntu-helm
**Local mirror**: `~/coding/mirrors/jellybuntu-helm`
**Protected branch**: `main`

## Kustomization Chain

```
flux-system (root)
  └─ infrastructure  (Traefik, MetalLB, NFS provisioner, NVIDIA device plugin)
       ├─ media       (sonarr, radarr, lidarr, prowlarr, bazarr, navidrome, ...)
       ├─ gpu         (jellyfin, tdarr)
       ├─ net         (Traefik config, middleware)
       └─ ops         (matrix, teamspeak)
```

Poll interval: **1 min**. Reconcile interval: **10 min**.

## Update a Service

```bash
cd ~/coding/mirrors/jellybuntu-helm
git checkout main && git pull
git checkout -b feature/update-<service>

# Edit the HelmRelease
$EDITOR clusters/jellybuntu/<namespace>/<service>.yaml

git add clusters/jellybuntu/<namespace>/<service>.yaml
git commit -m "chore(<service>): bump to vX.Y.Z"
git push -u origin feature/update-<service>
# Open PR → merge → Flux reconciles within 1 min
```

## Force Reconcile

```bash
# Sync git source first
flux reconcile source git flux-system -n flux-system

# Then reconcile a specific kustomization
flux reconcile kustomization <namespace> -n flux-system
```

## Status Checks

```bash
flux get kustomizations -A
flux get helmreleases -A
flux get sources git -A
```

## Edit Secrets

Secrets are SOPS-encrypted with age. Edit in-place — no plaintext written to disk.

```bash
sops ~/coding/mirrors/jellybuntu-helm/clusters/jellybuntu/<namespace>/secrets.yaml
```

After editing, commit + PR + merge. Flux decrypts via the `sops-age` secret in `flux-system`.

**Age public key**: `age1qt6zwvjzpvz8sed88tf3wj96t7694nnprnqdjls0w9vkxzzm6d8qag8snq`

## Suspend / Resume

```bash
# Pause reconciliation (e.g. during maintenance)
flux suspend kustomization media -n flux-system

# Resume
flux resume kustomization media -n flux-system
```

## Add a New Service

1. Create `clusters/jellybuntu/<namespace>/<service>.yaml` (HelmRelease CRD)
2. Add the file to `clusters/jellybuntu/<namespace>/kustomization.yaml`
3. Commit + PR + merge → Flux detects and deploys

## See Also

- [jellybuntu-helm Repo Layout](../reference/helm-repo-layout.md)
- [k3s Namespace Reference](../reference/k3s-namespaces.md)
- [k3s Cluster Deployment](k3s-cluster.md)
