# Backups

> Btrfs snapshot automation on the NAS VM. Snapshots are managed by the
> [`btrfs_snapshots`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/btrfs_snapshots)
> role via a systemd timer.

## Overview

All persistent data lives on the NAS VM (`192.168.30.15`) under `/mnt/storage/data`, which is a
Btrfs filesystem. Snapshots are taken automatically and retained according to the schedule below.

| Retention | Count |
|---|---|
| Daily | 3 |
| Weekly | 2 |
| Monthly | 1 |

Snapshots run daily at **03:00** via a systemd timer (`snapshot-manager.timer`).

## Snapshot Location

Snapshots are stored as Btrfs subvolume snapshots on the NAS. The `snapshot-manager.sh` script
handles creation and pruning based on the retention policy.

```bash
# Check timer status on NAS
ssh nas.discus-moth.ts.net sudo systemctl status snapshot-manager.timer

# View snapshot log
ssh nas.discus-moth.ts.net sudo journalctl -u snapshot-manager.service -n 50

# List existing snapshots
ssh nas.discus-moth.ts.net sudo btrfs subvolume list /mnt/storage
```

## Manual Snapshot

Take an out-of-schedule snapshot before a risky change:

```bash
ssh nas.discus-moth.ts.net sudo /usr/local/bin/snapshot-manager.sh
```

## Recovery Procedure

### Step 1: Identify the snapshot to restore

```bash
ssh nas.discus-moth.ts.net sudo btrfs subvolume list /mnt/storage
```

Snapshots are named by date/type (daily, weekly, monthly).

### Step 2: Stop services using the data

Stop any services on VMs that have NFS mounts to avoid writes during recovery:

```bash
# Example: stop Jellyfin on the jellyfin VM
ssh jellyfin.discus-moth.ts.net sudo systemctl stop jellyfin
```

For k3s workloads, scale down the relevant deployment:

```bash
kubectl scale deployment <name> -n <namespace> --replicas=0
```

### Step 3: Restore from snapshot

Btrfs snapshots are read-only subvolumes. To restore, replace the live subvolume:

```bash
# On NAS — replace live data subvolume with snapshot
ssh nas.discus-moth.ts.net
sudo btrfs subvolume snapshot /mnt/storage/.snapshots/<snapshot-name> /mnt/storage/data-restore
# Swap directories, then rename
sudo mv /mnt/storage/data /mnt/storage/data-old
sudo mv /mnt/storage/data-restore /mnt/storage/data
```

### Step 4: Restart services

```bash
# Restart NFS export (if needed)
ssh nas.discus-moth.ts.net sudo systemctl restart nfs-kernel-server

# Restart stopped services
ssh jellyfin.discus-moth.ts.net sudo systemctl start jellyfin

# Scale k3s workloads back up
kubectl scale deployment <name> -n <namespace> --replicas=1
```

## Re-deploying the Snapshot Role

If the timer or script needs to be reinstalled:

```bash
./bin/runtime/ansible-run.sh playbooks/infrastructure/nas.yml
```

## Proxmox VM Backups

Proxmox-level VM backups are configured separately in the Proxmox UI (Datacenter → Backup).
These complement Btrfs snapshots and cover the full VM disk state.
