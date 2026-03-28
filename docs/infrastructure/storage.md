# Storage

> Btrfs single-disk (temporary), NFS exports, NFS-backed PVCs.

## NAS Overview

The NAS VM (VMID 300, 192.168.30.15) is the central storage server. Physical disks are passed through
from the Proxmox host to the VM via the `bpg/proxmox` Terraform provider (post-deployment passthrough
configured by Ansible).

**Current state:** single-drive temporary configuration (one WD Gold 6 TB, serial K1HDZ8GD, appearing as
`/dev/sdb` inside the VM). The permanent configuration is three-way Btrfs RAID1 pending replacement drives.

| Setting | Current (temporary) | Target (permanent) |
|---------|--------------------|--------------------|
| Drives | 1x WD Gold 6 TB | 3x WD Gold 6 TB |
| Btrfs data profile | `single` | `raid1` |
| Btrfs metadata profile | `single` | `raid1` |
| Mount point | `/mnt/storage` | `/mnt/storage` |

Source:
[`host_vars/nas.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/nas.yml),
[`roles/btrfs_storage/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/btrfs_storage)

## NFS Exports

NFS listens on port 2049 (TCP). NFSv3 and NFSv4 are enabled; NFSv2 is disabled. The server runs 16
threads.

Direct LAN IP `192.168.30.15` is used for all NFS mounts rather than the Tailscale hostname to avoid
DNS resolution latency and the Tailscale MTU overhead on high-throughput transfers.

| Export Path | Networks | Options | Purpose |
|-------------|----------|---------|---------|
| `/mnt/storage/data` | 192.168.0.0/24 (legacy), 192.168.30.0/24, 100.64.0.0/10 | rw, sync, no\_subtree\_check, all\_squash, anonuid=3000, anongid=3000 | Media and config data for all VMs and k3s |
| `/mnt/storage/lancache` | 192.168.40.18/32 | rw, sync, no\_subtree\_check, no\_root\_squash | Lancache VM cache storage (needs chown) |

The legacy `192.168.0.0/24` entry on `/mnt/storage/data` will be removed when the flat network is fully
decommissioned (Phase 2).

Source:
[`roles/nfs_server/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/nfs_server)

## Client Mounts

All VMs that consume NFS mount `/mnt/storage/data` from the NAS. The mount options used by the NFS client
role are:

```text
rw, hard, nfsvers=4, noexec, nosuid
```

UID/GID squashing (`all_squash`, `anonuid=3000`, `anongid=3000`) maps all client requests to UID/GID 3000
on the server side. This resolves the UID namespace mismatch for rootless Podman containers: a container
running as UID 3000 maps to host UID 102999 inside the VM, but the NFS server sees UID 3000 because of
`all_squash`. Files on disk are owned by `3000:3000`.

Source:
[`roles/nfs_client/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/nfs_client)

## k8s Persistent Volumes

### NFS Subdir Provisioner

k3s uses the NFS Subdir External Provisioner to dynamically provision PVCs backed by `/mnt/storage/data`
on the NAS. The StorageClass is named `nfs-client`.

Services in the `gpu`, `media`, and `ops` namespaces request `nfs-client` PVCs for config storage
(5 Gi for Jellyfin, 2 Gi + 1 Gi for Tdarr, etc.).

### Static Media PV

A static 1 Ti PersistentVolume (`nfs-media-gpu`) is pre-provisioned and shared between Jellyfin and
Tdarr in the `gpu` namespace:

```yaml
nfs:
  server: 192.168.30.15
  path: /mnt/storage/data
mountOptions:
  - hard
  - nfsvers=4
  - noexec
  - nosuid
```

Both pods mount this PV at `/data` (read-write-many).

Source:
[`clusters/jellybuntu/gpu/nfs-media-pv.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/clusters/jellybuntu/gpu/nfs-media-pv.yaml)

### NVMe-backed NFS (Proxmox host)

The Proxmox host can optionally export a thin LV (`pve/k8s-config`) as a secondary NFS share for
high-IOPS config PVCs. This is controlled by `proxmox_nfs_export_enabled` in the `proxmox_host` role
(default: `false`). When enabled:

- Size: 10 GB (configurable via `proxmox_nfs_export_size`)
- Path: `/mnt/k8s-config` on the Proxmox host
- Network: `192.168.30.0/24`, `no_root_squash`
- Filesystem: ext4 on a thin-provisioned LV from `pve/data`

Source:
[`roles/proxmox_host/tasks/nfs_export.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/proxmox_host/tasks/nfs_export.yml)

## Transcode Cache

Jellyfin and Tdarr use local `hostPath` volumes on the k8s-gpu node for transcode scratch space (not NFS),
avoiding NFS overhead during active transcoding:

- Jellyfin: `/mnt/transcode-cache/jellyfin` -> container `/config/data/transcodes`
- Tdarr: `/mnt/transcode-cache/tdarr` -> container `/temp`
