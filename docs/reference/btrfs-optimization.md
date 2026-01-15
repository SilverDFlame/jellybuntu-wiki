# Btrfs Optimization Guide

Performance tuning and optimization strategies for the Btrfs RAID1 NAS storage system.

## Overview

The NAS VM uses Btrfs RAID1 across two 1TB drives for reliable network storage. This guide covers filesystem tuning,
mount options, snapshot management, and maintenance procedures for optimal performance.

## Current Configuration

```bash
# View current mount options
mount | grep /mnt/storage

# Typical output:
# /dev/sda on /mnt/storage type btrfs (rw,relatime,space_cache=v2,subvolid=5)
```

## Optimized Mount Options

### Recommended Mount Options for NAS Workload

Edit `/etc/fstab` on NAS VM:

```bash
UUID=xxx-xxx /mnt/storage btrfs defaults,compress=zstd:3,noatime,autodefrag 0 0
```

**Options Explained**:

| Option | Purpose | Impact |
|--------|---------|--------|
| `compress=zstd:3` | Transparent compression | +20-30% space savings, minimal CPU |
| `noatime` | Don't update access time | Reduces write operations |
| `autodefrag` | Auto defragment small files | Better small file performance |
| `space_cache=v2` | Free space cache v2 | Faster mount times (default) |
| `commit=300` | Sync every 5 minutes | Optional: reduces write frequency |

### Apply New Mount Options

```bash
# SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Edit fstab
sudo nano /etc/fstab

# Update mount options
# Before: defaults
# After:  defaults,compress=zstd:3,noatime,autodefrag

# Remount to apply (only works for some options)
sudo mount -o remount /mnt/storage

# Or reboot for all options to take effect
sudo reboot
```

### Verify Options Applied

```bash
mount | grep /mnt/storage
# Should show: rw,noatime,compress=zstd:3,autodefrag...
```

## Compression

### Enable Compression

Compression saves significant space with minimal CPU overhead:

```bash
# Enable on existing files (one-time)
sudo btrfs filesystem defragment -r -czstd /mnt/storage

# Check compression ratio
sudo compsize /mnt/storage

# Example output:
# Processed 50000 files, 450GB total
# Compressed: 360GB (80% of original)
# Saved: 90GB
```

### Compression Levels

| Level | Compression | Speed | Use Case |
|-------|-------------|-------|----------|
| `zstd:1` | ~20% | Fastest | Real-time writes |
| `zstd:3` | ~30% | Balanced | **Recommended (default)** |
| `zstd:9` | ~35% | Slower | Archival data |
| `lzo` | ~15% | Very fast | Legacy, less effective |
| `zlib:9` | ~35% | Slowest | Maximum compression |

**Recommendation**: `zstd:3` provides excellent balance.

### Check Which Files Are Compressed

```bash
# Install compsize tool
sudo apt install btrfs-compsize

# Check compression stats
sudo compsize /mnt/storage
sudo compsize /mnt/storage/media/movies
```

## Snapshot Management

### Create Snapshots

```bash
# Manual snapshot
sudo btrfs subvolume snapshot \
  /mnt/storage \
  /mnt/storage/.snapshots/manual-$(date +%Y%m%d-%H%M)

# Read-only snapshot (recommended for backups)
sudo btrfs subvolume snapshot -r \
  /mnt/storage \
  /mnt/storage/.snapshots/backup-$(date +%Y%m%d)
```

### Automated Daily Snapshots

Create systemd timer for automatic snapshots:

```bash
# Create snapshot script
sudo nano /usr/local/bin/btrfs-snapshot.sh
```

Add content:

```bash
#!/bin/bash
SNAPSHOT_DIR="/mnt/storage/.snapshots"
DATE=$(date +%Y%m%d)

# Create snapshot
btrfs subvolume snapshot -r /mnt/storage "$SNAPSHOT_DIR/daily-$DATE"

# Keep only last 7 daily snapshots
find "$SNAPSHOT_DIR" -name "daily-*" -type d -mtime +7 -exec btrfs subvolume delete {} \;
```

```bash

# Make executable
sudo chmod +x /usr/local/bin/btrfs-snapshot.sh

# Create service
sudo nano /etc/systemd/system/btrfs-snapshot.service
```

Add:

```ini
[Unit]
Description=Btrfs Daily Snapshot
[Service]
Type=oneshot
ExecStart=/usr/local/bin/btrfs-snapshot.sh
```

```bash
# Create timer
sudo nano /etc/systemd/system/btrfs-snapshot.timer
```

Add:

```ini
[Unit]
Description=Daily Btrfs Snapshot Timer
[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true
[Install]
WantedBy=timers.target
```

```bash

# Enable
sudo systemctl daemon-reload
sudo systemctl enable --now btrfs-snapshot.timer
```

### Snapshot Retention Policy

Recommended retention:

- **Hourly**: Keep 24 hours
- **Daily**: Keep 7 days
- **Weekly**: Keep 4 weeks
- **Monthly**: Keep 6 months

### List Snapshots

```bash
sudo btrfs subvolume list /mnt/storage

# Show snapshot sizes
sudo btrfs subvolume show /mnt/storage/.snapshots/daily-20241028
```

### Delete Snapshot

```bash
# Delete specific snapshot
sudo btrfs subvolume delete /mnt/storage/.snapshots/old-snapshot

# Delete all old snapshots
sudo find /mnt/storage/.snapshots -name "daily-*" -mtime +7 \
  -exec btrfs subvolume delete {} \;
```

### Restore from Snapshot

```bash
# Method 1: Copy files from snapshot
sudo cp -a /mnt/storage/.snapshots/daily-20241028/media/file.mkv \
  /mnt/storage/media/

# Method 2: Replace entire subvolume (destructive!)
sudo btrfs subvolume delete /mnt/storage
sudo btrfs subvolume snapshot /mnt/storage/.snapshots/daily-20241028 /mnt/storage
```

## Scrubbing (Data Integrity Check)

Scrub verifies and repairs data integrity across RAID1 mirrors.

### Manual Scrub

```bash
# Start scrub
sudo btrfs scrub start /mnt/storage

# Check status
sudo btrfs scrub status /mnt/storage

# Example output:
# scrub status for xxx:
#   total bytes scrubbed: 800GB
#   errors: 0
#   corrected: 0
```

### Automated Monthly Scrub

```bash
# Create service
sudo nano /etc/systemd/system/btrfs-scrub.service
```

Add:

```ini
[Unit]
Description=Btrfs Monthly Scrub
[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start -B /mnt/storage
```

```bash
# Create timer
sudo nano /etc/systemd/system/btrfs-scrub.timer
```

Add:

```ini
[Unit]
Description=Monthly Btrfs Scrub
[Timer]
OnCalendar=monthly
OnCalendar=*-*-01 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
```

```bash

# Enable
sudo systemctl daemon-reload
sudo systemctl enable --now btrfs-scrub.timer
```

### Scrub Frequency

**Recommendation**: Monthly scrub for home NAS

- Catches bit rot early
- Validates RAID1 mirrors match
- Minimal performance impact

## Defragmentation

### When to Defragment

Defragment if:

- Many small files written/updated
- Database files (SQLite) with frequent writes
- Performance degradation noticed

### Manual Defragmentation

```bash
# Defragment specific directory
sudo btrfs filesystem defragment -r /mnt/storage/media/tv

# Defragment with compression
sudo btrfs filesystem defragment -r -czstd /mnt/storage/media

# Defragment entire filesystem (takes hours for TB of data)
sudo btrfs filesystem defragment -r -czstd /mnt/storage
```

### Autodefrag Mount Option

Already recommended in mount options:

```bash
mount -o autodefrag
```

Automatically defragments small files during writes (< 64KB).

## Balance Operations

Balance redistributes data across drives, useful after adding/removing drives.

### Check Balance Status

```bash
sudo btrfs balance status /mnt/storage
```

### Run Balance (Rarely Needed)

```bash
# Balance data
sudo btrfs balance start -dusage=50 /mnt/storage

# Balance metadata
sudo btrfs balance start -musage=50 /mnt/storage

# Full balance (very slow, rarely needed)
sudo btrfs balance start /mnt/storage
```

**Warning**: Balance is I/O intensive. Only run if:

- After adding/removing drives
- Filesystem showing "No space" but `df` shows space available
- Recommended by Btrfs community for specific issue

## Performance Monitoring

### Check Filesystem Stats

```bash
# Overall stats
sudo btrfs filesystem show /mnt/storage

# Disk usage
sudo btrfs filesystem df /mnt/storage

# Detailed usage
sudo btrfs filesystem usage /mnt/storage
```

### Monitor I/O Performance

```bash
# Real-time I/O stats
sudo iostat -x 1

# Watch specific drives
sudo iostat -x /dev/sda /dev/sdb 1

# Btrfs-specific stats
sudo btrfs device stats /mnt/storage
```

### Detect Performance Issues

```bash
# Check for errors
sudo btrfs device stats /mnt/storage

# Should show all zeros:
# [/dev/sda].write_io_errs: 0
# [/dev/sda].read_io_errs: 0
# [/dev/sda].corruption_errs: 0

# If non-zero, investigate drive health
sudo smartctl -a /dev/sda
```

## RAID Maintenance

### Check RAID Status

```bash
# RAID information
sudo btrfs filesystem show /mnt/storage

# Should show:
# Label: 'nas-storage'  uuid: xxx
#   Total devices 2 FS bytes used XXX GB
#   devid    1 size 1TB used XXX GB path /dev/sda
#   devid    2 size 1TB used XXX GB path /dev/sdb
```

### Replace Failed Drive

If a drive fails:

```bash
# Check RAID status (will show degraded)
sudo btrfs filesystem show /mnt/storage

# Replace drive (assuming /dev/sdb failed, new drive is /dev/sdc)
sudo btrfs replace start /dev/sdb /dev/sdc /mnt/storage

# Monitor replacement
sudo btrfs replace status /mnt/storage

# Takes several hours for 1TB drive
```

### Add Drive to Expand RAID

```bash
# Add new drive
sudo btrfs device add /dev/sdc /mnt/storage

# Rebalance to use new space
sudo btrfs balance start -dusage=0 /mnt/storage
```

## Troubleshooting Performance Issues

### Slow NFS Performance

```bash
# Check NFS stats
nfsstat -c

# Check network throughput
iperf3 -c nas.discus-moth.ts.net

# Verify mount options
mount | grep /mnt/data
```

See [NAS/NFS Troubleshooting](../troubleshooting/nas-nfs.md) for detailed NFS optimization.

### High CPU Usage During Writes

```bash
# Check if compression is too aggressive
mount | grep compress

# If using zstd:9, reduce to zstd:3
sudo nano /etc/fstab
# Change compress=zstd:9 to compress=zstd:3
sudo mount -o remount /mnt/storage
```

### Filesystem Full But df Shows Space

```bash
# Check metadata usage
sudo btrfs filesystem df /mnt/storage

# If metadata is full, balance
sudo btrfs balance start -musage=50 /mnt/storage
```

### Btrfs Errors in Logs

```bash
# Check system logs
sudo journalctl -u btrfs* | grep -i error

# Check device errors
sudo btrfs device stats /mnt/storage

# Run scrub to detect/fix
sudo btrfs scrub start -B /mnt/storage
```

## Best Practices Summary

1. **Mount Options**: Use `compress=zstd:3,noatime,autodefrag`
2. **Snapshots**: Daily snapshots, 7-day retention
3. **Scrubbing**: Monthly scrub for data integrity
4. **Defragmentation**: Use autodefrag, manual defrag yearly
5. **Monitoring**: Check `btrfs device stats` monthly
6. **Backups**: Snapshots are NOT backups - maintain separate backups

## Advanced Tuning

### SSD-Specific Optimizations

If using SSDs (not applicable to current setup with HDDs):

```bash
# Add SSD mount option
mount -o ssd,discard=async

# In /etc/fstab:
defaults,compress=zstd:3,noatime,autodefrag,ssd,discard=async
```

### Increase Metadata to Data Ratio

For many small files:

```bash
# Convert some data space to metadata
sudo btrfs balance start -mconvert=dup /mnt/storage
```

## See Also

- [NAS Setup Reference](nas-setup.md)
- [Backup and Recovery Procedures](../maintenance/backup-recovery.md)
- [NAS/NFS Troubleshooting](../troubleshooting/nas-nfs.md)
