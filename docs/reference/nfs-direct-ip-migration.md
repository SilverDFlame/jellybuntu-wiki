# NFS Direct IP Migration

This document explains why NFS mounts were changed from Tailscale hostname to direct IP addressing.

## Summary

| Setting | Before | After |
|---------|--------|-------|
| NFS Server | `nas.discus-moth.ts.net` | `192.168.0.15` |
| Network Path | Tailscale WireGuard tunnel | Local network (eth0) |
| Boot Dependency | Required Tailscale to be connected | Standard network only |

## Problem Statement

Heavy NFS traffic (particularly sustained writes) overwhelmed the Tailscale UDP tunnel, causing:

1. **Connection drops**: Tailscale's magicsock component would fail to send packets
2. **Load spikes**: VMs showed load averages of 264+ despite 86% CPU idle (processes stuck in D state)
3. **Mount hangs**: When Tailscale recovered, NFS mounts would hang waiting for stale connections
4. **Boot failures**: VMs required Tailscale to be connected before NFS could mount

### Symptoms Observed

On `download-clients` VM (qBittorrent + SABnzbd):

```text
# Tailscale errors during heavy NFS writes
magicsock: send to 100.65.73.89:41641: operation not permitted
magicsock: send UDP failed: write udp 192.168.0.14:41641->100.65.73.89:41641: operation not permitted

# System load during NFS stall
05:27:20 up 5:41, load average: 264.84, 199.71, 109.53
# But CPU was 86% idle - processes stuck waiting for NFS I/O
```

### Root Cause

1. **Tailscale tunnels all traffic**: NFS mounted via `nas.discus-moth.ts.net` routes through Tailscale
2. **UDP buffer limits**: Tailscale uses UDP with limited buffer sizes (~212KB)
3. **Sustained write load**: Download clients write 14+ MB/s continuously
4. **No backpressure**: NFS doesn't throttle when the tunnel is overwhelmed

## Solution

Changed NFS server address from Tailscale hostname to direct local IP:

```yaml
# Before
nfs_server: "nas.discus-moth.ts.net"

# After
nfs_server: "192.168.0.15"
```

### Why This Works

1. **Direct path**: Traffic goes over eth0 directly to NAS on local network
2. **No tunnel overhead**: Eliminates WireGuard encryption/encapsulation
3. **TCP reliability**: NFS uses TCP which handles congestion properly
4. **Simpler boot**: No Tailscale dependency for storage access

### What About Security?

Tailscale provides encryption, but for NFS traffic on a local home network:

- Traffic stays within `192.168.0.0/24` subnet
- NFS exports already restrict access by IP range
- Tailscale remains available for remote access to services
- No sensitive data transits the public internet

### IP Address Stability

> **IMPORTANT**: The NAS must have a stable IP address (192.168.0.15).
>
> Configure one of the following on your router/DHCP server:
>
> - **DHCP Reservation** (recommended) - Reserve 192.168.0.15 for the NAS MAC address
> - **Static IP** - Configure static IP directly on the NAS
>
> If the NAS IP changes, all NFS mounts across the infrastructure will fail.

## Performance Comparison

### Baseline (Tailscale Mount)

Tested on `download-clients` VM:

```text
Write (500MB): 44.2 MB/s (11.87 seconds)
Read (500MB):  228 MB/s (2.3 seconds)
```

### Direct IP Mount

After migration, performance measured on `download-clients` VM:

```text
Write (500MB): 42.9 MB/s (12.2 seconds)
Read (500MB):  1.3 GB/s (0.41 seconds)
```

| Metric | Tailscale | Direct IP | Improvement |
|--------|-----------|-----------|-------------|
| Write | 44.2 MB/s | 42.9 MB/s | Similar (NAS disk-limited) |
| Read | 228 MB/s | 1.3 GB/s | **5.7x faster** |

**Key benefits**:

1. **Read performance**: 5.7x faster reads by eliminating tunnel overhead
2. **Reliability**: No more Tailscale tunnel failures under sustained load
3. **Simplified boot**: No Tailscale dependency for storage access

## Migration Steps

### 1. Update Configuration

Changes made to:

- [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml): Primary `nfs_server` variable
- [`host_vars/lancache.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/lancache.yml): Lancache-specific NFS server
- [`bin/bootstrap/lib/06-generate-configs.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/bin/bootstrap/lib/06-generate-configs.sh): Bootstrap template

### 2. Apply NFS Changes

```bash
./bin/runtime/ansible-run.sh playbooks/core/09-configure-nfs-clients-role.yml
```

### 3. Remove Tailscale Dependencies

The Tailscale wait service was created to handle boot timing issues. With direct IP, it's no longer needed:

```bash
./bin/runtime/ansible-run.sh playbooks/utility/remove-nfs-tailscale-dependency.yml
```

This removes:

- `/usr/local/bin/tailscale-wait-online`
- `/etc/systemd/system/tailscale-wait-online.service`
- `/etc/systemd/system/mnt-data.mount.d/tailscale-dependency.conf`

### 4. Verify

```bash
# Check mount uses direct IP
mount | grep /mnt/data
# Should show: 192.168.0.15:/mnt/storage/data on /mnt/data

# Verify data accessible
ls /mnt/data/media
```

## Rollback

If issues occur, revert to Tailscale mounting:

```bash
# Quick manual fix on affected VM
sudo umount /mnt/data
sudo mount -t nfs nas.discus-moth.ts.net:/mnt/storage/data /mnt/data \
  -o rw,async,hard,intr,nfsvers=4,_netdev,noatime,nodiratime,rsize=1048576,wsize=1048576

# Full configuration rollback
git checkout main -- group_vars/all.yml host_vars/lancache.yml
./bin/runtime/ansible-run.sh playbooks/core/09-configure-nfs-clients-role.yml
# Re-apply Tailscale dependency fix from archive
./bin/runtime/ansible-run.sh playbooks/archive/utility/fix-nfs-tailscale-dependency.yml
```

## Affected VMs

| VM | IP | NFS Mount Point |
|----|-----|-----------------|
| jellyfin | 192.168.0.12 | /mnt/data |
| media-services | 192.168.0.13 | /mnt/data |
| download-clients | 192.168.0.14 | /mnt/data |
| lancache | 192.168.0.18 | /mnt/lancache |

## Related Documentation

- [NAS Setup Reference](nas-setup.md)
- [NFS Troubleshooting](../troubleshooting/nas-nfs.md)
- [Network Configuration](../configuration/networking.md)

## Implementation Date

January 2026
