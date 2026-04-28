# jellybuntu-helm Repo Layout

**Repo**: SilverDFlame/jellybuntu-helm
**Local mirror**: `~/coding/mirrors/jellybuntu-helm`
**Protected branch**: `main` — always branch + PR, never push direct

## Directory Structure

```text
clusters/jellybuntu/
├── flux-system/              # Flux bootstrap (auto-generated, do not edit)
├── kustomization.yaml        # Root kustomization
├── infrastructure.yaml       # Flux Kustomization CRD (layer 1)
├── infrastructure/
│   └── controllers/
│       ├── namespaces.yaml
│       ├── traefik/
│       ├── metallb/
│       ├── nfs-provisioner/
│       └── nvidia-device-plugin/
├── media.yaml                # Flux Kustomization CRD (layer 2)
├── media/
│   ├── kustomization.yaml
│   ├── secrets.yaml          # SOPS-encrypted
│   ├── storage.yaml          # nfs-media PV + PVC (1 Ti)
│   ├── middleware.yaml       # Traefik admin-ipallowlist
│   └── <service>.yaml        # One HelmRelease per service
├── gpu.yaml
├── gpu/
│   ├── kustomization.yaml
│   ├── storage.yaml          # nfs-media-gpu PV + PVC (1 Ti)
│   ├── jellyfin.yaml
│   └── tdarr.yaml
├── net.yaml
├── net/
│   └── kustomization.yaml
├── ops.yaml
└── ops/
    ├── kustomization.yaml
    ├── matrix/
    └── teamspeak/
```

## Helm Sources

All workload HelmReleases use `app-template`. Infrastructure controllers use dedicated charts.

| Chart | Source Type | Repository | Version |
|---|---|---|---|
| traefik | HelmRepository | traefik.github.io/charts | v39.0.5 |
| metallb | HelmRepository | metallb.github.io/metallb | v0.15.3 |
| nfs-subdir-external-provisioner | HelmRepository | kubernetes-sigs.github.io/nfs-subdir-external-provisioner | v4.0.18 |
| nvidia-device-plugin | HelmRepository | nvidia.github.io/k8s-device-plugin | v0.18.2 |
| app-template | OCIRepository | ghcr.io/bjw-s-labs/helm/app-template | 4.6.x |

> Versions from training data — verify before bumping: `flux get sources helm -A`

## SOPS Encryption

Files matching `.*secrets.*\.yaml$` are encrypted at rest. Edit with:

```bash
sops clusters/jellybuntu/<namespace>/secrets.yaml
```

Flux decrypts using the `sops-age` secret in `flux-system`. Age pubkey:
`age1qt6zwvjzpvz8sed88tf3wj96t7694nnprnqdjls0w9vkxzzm6d8qag8snq`

## app-template Notes

- Uses bjw-s `app-template` v4.x — check chart schema before guessing field names
- `storageClass` (not `storageClassName`) in v4.x
- All workloads share a single OCI source ref; pin per-release with `spec.chart.spec.version`

## See Also

- [k3s Cluster Operations](k3s-cluster.md)
- [k3s Namespace Reference](k3s-namespaces.md)
