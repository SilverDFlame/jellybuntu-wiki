# NAS Setup Guide

Custom Btrfs-based NAS replacing TrueNAS Scale for the Jellybuntu homelab.

## Overview

**Platform:** Ubuntu 24.04 LTS (cloud-init)
**Filesystem:** Btrfs RAID1
**Storage:** 2x 500GB (mirrored)
**RAM:** 6GB (reduced from 16GB)
**Services:** NFS, Automated Snapshots, Weekly Maintenance

## Architecture

### VM Specifications (VMID 300)

```text
Name:         nas
IP Address:   192.168.30.15 (DHCP reservation required)
Hostname:     nas.discus-moth.ts.net
Cores:        2 (shared)
Memory:       6GB
Boot Disk:    32GB (SCSI0)
Data Disks:   500GB (SCSI1) + 500GB (SCSI2)
Network:      192.168.30.0/24 + Tailscale (100.64.0.0/10)
```

> **IMPORTANT**: The NAS IP (192.168.30.15) must be stable. Configure a DHCP reservation
> on your router for the NAS MAC address, or set a static IP on the NAS itself.
> All NFS client VMs depend on this address.

### Storage Layout

```text
/dev/sda            → 32GB boot disk (ext4)
/dev/sdb + /dev/sdc → 500GB each (Btrfs RAID1)

/mnt/storage/
├── @data/                          # Main data subvolume
│   ├── media/
│   │   ├── tv/
│   │   └── movies/
│   ├── torrents/
│   │   ├── tv/
│   │   ├── movies/
│   │   └── incomplete/
│   └── usenet/
│       ├── tv/
│       ├── movies/
│       └── incomplete/
└── @snapshots/                     # Snapshot subvolume
    └── @data/
        ├── daily/                  # 7 days retention
        ├── weekly/                 # 4 weeks retention
        └── monthly/                # 6 months retention
```

### Btrfs Features

- **RAID1:** Data and metadata mirrored across both disks
- **Compression:** zstd level 3 (transparent, space-saving)
- **Snapshots:** Daily, weekly, monthly (automated)
- **Scrubbing:** Weekly integrity checks (Sunday 2 AM)
- **Self-healing:** Automatic error correction from mirrors

## Deployment

### Prerequisites

1. Proxmox VE with VM template created
2. Ansible control machine configured
3. Vault configured with NFS UID/GID (3000)

### Automated Deployment

```bash
cd /home/olieran/coding/mirrors/jellybuntu

# 1. Provision NAS VM (via cloud-init)
./bin/runtime/ansible-run.sh playbooks/infrastructure/provision-vms.yml

# 2. Configure NAS storage and services
./bin/runtime/ansible-run.sh playbooks/infrastructure/nas.yml

# 3. Configure Tailscale VPN
./bin/runtime/ansible-run.sh playbooks/networking/tailscale.yml

# 4. Configure NFS clients
./bin/runtime/ansible-run.sh playbooks/networking/nfs-clients.yml
```

### What Gets Configured

Playbook `02-configure-nas-role.yml` executes 4 roles:

1. **btrfs_storage** - Creates Btrfs RAID1, subvolumes, directory structure
2. **nfs_server** - Configures NFS exports and firewall rules
3. **btrfs_snapshots** - Installs automated snapshot manager
4. **btrfs_maintenance** - Installs automated scrub and health checks

## NFS Configuration

### Server Export

```text
Path: /mnt/storage/data
Allowed Networks:
  - 192.168.30.0/24 (local network)
  - 100.64.0.0/10 (Tailscale)
Options: rw,sync,no_subtree_check,root_squash (default)
Note: no_root_squash is only used for Lancache (required for chown operations)
```

### Client Mount Points

| VM | Hostname | Mount Point | Usage |
|----|----------|-------------|-------|
| Jellyfin | jellyfin.discus-moth.ts.net | /mnt/data | Media playback |
| Media Services | media-services.discus-moth.ts.net | /mnt/data | Sonarr/Radarr/Prowlarr |
| Download Clients | download-clients.discus-moth.ts.net | /mnt/data | qBittorrent/SABnzbd |

### Testing NFS

```bash
# From any client VM (use direct IP for NFS)
showmount -e 192.168.30.15

# Check mount
df -h /mnt/data

# Test write access
touch /mnt/data/test-$(hostname).txt
rm /mnt/data/test-$(hostname).txt
```

> **Note**: NFS mounts use direct IP (192.168.30.15) rather than Tailscale hostname for reliability.
> See [NFS Direct IP Migration](nfs-direct-ip-migration.md) for details.

## Snapshot Management

### Automated Schedule

| Type | Schedule | Retention | Timer |
|------|----------|-----------|-------|
| Daily | 3:00 AM | 7 days | snapshot-manager.timer |
| Weekly | Sunday 3:00 AM | 4 weeks | snapshot-manager.timer |
| Monthly | 1st of month 3:00 AM | 6 months | snapshot-manager.timer |

### Manual Snapshots

```bash
# Create manual snapshot
sudo btrfs subvolume snapshot -r /mnt/storage/@data \
  /mnt/storage/@snapshots/@data/manual-$(date +%Y%m%d-%H%M%S)

# List all snapshots
sudo btrfs subvolume list -s /mnt/storage

# Delete snapshot
sudo btrfs subvolume delete /mnt/storage/@snapshots/@data/daily-20250122-030000
```

### Restore from Snapshot

```bash
# 1. Stop services on clients
# 2. Unmount NFS on clients
sudo umount /mnt/data

# 3. On NAS, unmount data subvolume
sudo umount /mnt/storage/data

# 4. Delete current data subvolume
sudo btrfs subvolume delete /mnt/storage/@data

# 5. Restore from snapshot
sudo btrfs subvolume snapshot \
  /mnt/storage/@snapshots/@data/daily-20250121-030000 \
  /mnt/storage/@data

# 6. Remount
sudo mount /mnt/storage/@data /mnt/storage/data

# 7. Remount NFS on clients
sudo mount -a

# 8. Restart services
```

## Maintenance

### Automated Maintenance

**Schedule:** Sunday at 2:00 AM (maintenance.timer)

**Tasks:**

- Btrfs filesystem scrub (data integrity check)
- Device statistics check
- Filesystem usage monitoring
- SMART status checks
- Log rotation

### Manual Maintenance

```bash
# Check filesystem health
sudo btrfs device stats /mnt/storage
sudo btrfs filesystem usage /mnt/storage

# Run manual scrub
sudo btrfs scrub start /mnt/storage
sudo btrfs scrub status /mnt/storage

# Check NFS server
sudo systemctl status nfs-kernel-server
sudo exportfs -v
sudo nfsstat -s

# View logs
sudo tail -f /var/log/btrfs-snapshots.log
sudo tail -f /var/log/btrfs-maintenance.log
sudo journalctl -u nfs-kernel-server -f
```

## Monitoring

### System Resources

```bash
# Memory usage (should be ~2-3GB)
free -h

# Disk I/O
iostat -x 1

# NFS performance
nfsstat -c

# Network
iftop -i eth0
```

### Systemd Timers

```bash
# List all timers
systemctl list-timers

# Check snapshot timer
systemctl status snapshot-manager.timer

# Check maintenance timer
systemctl status maintenance.timer

# Manually trigger snapshot
sudo systemctl start snapshot-manager.service

# Manually trigger maintenance
sudo systemctl start maintenance.service
```

## Troubleshooting

### Btrfs Issues

```bash
# Check for errors
sudo dmesg | grep -i btrfs
sudo journalctl -u maintenance -n 100

# Check device stats
sudo btrfs device stats /mnt/storage

# Balance filesystem (if needed)
sudo btrfs balance start -dusage=50 /mnt/storage
```

### NFS Issues

```bash
# Restart NFS server
sudo systemctl restart nfs-kernel-server

# Check exports
sudo exportfs -ra
sudo exportfs -v

# Check firewall
sudo ufw status verbose

# Test from client
showmount -e 192.168.30.15
```

### Permission Issues

```bash
# Check NFS user/group
id nfsuser
# Should show: uid=3000(nfsuser) gid=3000(nfsusers)

# Fix permissions
sudo chown -R 3000:3000 /mnt/storage/data
sudo chmod -R 775 /mnt/storage/data
```

## Performance Comparison

| Metric | TrueNAS Scale | Custom Btrfs NAS |
|--------|---------------|------------------|
| RAM Usage | 16GB | 6GB |
| Boot Time | ~2 min | ~30 sec |
| Management | Web UI | CLI/Ansible |
| ECC Required | Recommended | No |
| Complexity | High | Low |
| Automation | Limited | Full (Ansible) |

## Backup Strategy

**IMPORTANT:** Btrfs snapshots are NOT backups!

### Recommended Backup Options

1. **Off-site rsync** to another server
2. **USB drive backup** with periodic sync
3. **Cloud backup** (Backblaze B2, Wasabi)
4. **Secondary NAS** for replication

### Example Backup Script

```bash
#!/bin/bash
# backup-to-remote.sh

rsync -avhP --delete \
  /mnt/storage/data/ \
  backup-server:/backups/nas/
```

## Security

✅ SSH restricted to Tailscale network (100.64.0.0/10)
✅ NFS limited to trusted networks (192.168.30.0/24, 100.64.0.0/10)
✅ UFW firewall configured
✅ Automatic security updates enabled
✅ No root password login
✅ SSH keys only

## Migration from TrueNAS

If migrating from existing TrueNAS installation:

1. Backup all data from TrueNAS
2. Destroy TrueNAS VM (VMID 300)
3. Run deployment playbooks (01, 02, 03, 10)
4. Verify NFS access from all clients
5. Test services thoroughly

See archived `docs/archive/truenas-setup.md` for historical reference.

## References

- **Btrfs Documentation:** https://btrfs.readthedocs.io/
- **NFS Guide:** https://ubuntu.com/server/docs/service-nfs
- **Tailscale Docs:** https://tailscale.com/kb/
- **Proxmox Docs:** https://pve.proxmox.com/wiki/

## Support Commands

```bash
# Quick health check
sudo btrfs device stats /mnt/storage && \
sudo btrfs filesystem usage /mnt/storage && \
sudo exportfs -v && \
sudo systemctl status nfs-kernel-server

# View automation status
systemctl list-timers | grep -E "snapshot|maintenance"

# Check all logs
sudo tail -n 50 /var/log/btrfs-snapshots.log
sudo tail -n 50 /var/log/btrfs-maintenance.log
```
