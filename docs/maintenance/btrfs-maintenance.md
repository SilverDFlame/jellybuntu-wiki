# Btrfs Maintenance Guide

Guide for maintaining the Btrfs RAID1 filesystem on the NAS VM, including scrubs, balancing, snapshot management,
and health monitoring.

## Overview

The NAS VM uses Btrfs RAID1 across two 1TB drives (`/dev/sda` and `/dev/sdb`) for storage with automatic snapshots
and routine maintenance tasks.

**Filesystem Details**:

- **RAID Level**: RAID1 (mirrored data and metadata)
- **Mount Point**: `/mnt/storage`
- **Pool Name**: `pool`
- **Total Capacity**: ~1TB (2x 1TB drives in RAID1)
- **Automated Maintenance**: Scrubs, balancing, snapshot cleanup via systemd timers

**Key Features**:

- Automatic snapshots for data protection
- Scheduled scrubs for data integrity verification
- Automatic space reclamation via balance operations
- Disk health monitoring

## Routine Maintenance Overview

### Automated Maintenance Tasks

The following tasks run automatically via systemd timers (configured during deployment):

| Task | Frequency | Purpose | Timer Unit |
|------|-----------|---------|------------|
| **Scrub** | Monthly (1st of month, 2 AM) | Verify data integrity, detect corruption | `btrfs-scrub.timer` |
| **Balance** | Quarterly (1st, 4th, 7th, 10th month) | Rebalance data across drives | `btrfs-balance.timer` |
| **Snapshot cleanup** | Daily (3 AM) | Remove expired snapshots | `btrfs-snapshot-cleanup.timer` |

**No manual intervention required** - these tasks run automatically and log to systemd journal.

### Manual Maintenance Tasks

| Task | Frequency | Purpose |
|------|-----------|---------|
| **Health check** | Weekly | Verify filesystem and SMART health |
| **Snapshot verification** | Weekly | Ensure snapshots are being created |
| **Disk usage review** | Weekly | Monitor storage capacity |
| **RAID status check** | Monthly | Verify RAID1 integrity |

## Health Checks

### Quick Health Check

Run weekly to verify filesystem health:

```bash
# SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Filesystem status (shows RAID level, usage, devices)
sudo btrfs filesystem show /mnt/storage

# Disk space usage
sudo btrfs filesystem usage /mnt/storage

# Check for errors
sudo btrfs device stats /mnt/storage
```

**Expected output** (`btrfs device stats`):

```text
[/dev/sda].write_io_errs    0
[/dev/sda].read_io_errs     0
[/dev/sda].flush_io_errs    0
[/dev/sda].corruption_errs  0
[/dev/sda].generation_errs  0
[/dev/sdb].write_io_errs    0
[/dev/sdb].read_io_errs     0
...
```

**If any counter > 0**: See "Troubleshooting Disk Errors" section below.

### Comprehensive Health Report

```bash
# Run full health report script
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo /usr/local/bin/btrfs-health-check.sh"
```

**Report includes**:

- Filesystem usage and allocation
- RAID status and device health
- Recent scrub results
- Snapshot status
- SMART disk health (if available)

## Scrub Operations

Scrubs verify data integrity by reading all data blocks and checking checksums. Critical for detecting silent data corruption.

### Check Scrub Status

```bash
# View last scrub results
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs scrub status /mnt/storage"
```

**Expected output**:

```text
UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Scrub started:    Mon Dec  1 02:00:01 2025
Status:           finished
Duration:         0:15:42
Total to scrub:   450GiB
Rate:             47.84MiB/s
Error summary:    no errors found
```

**Key indicators**:

- **Status**: Should show "finished" (if recently completed) or "no errors found"
- **Error summary**: Should always be "no errors found"
- **Duration**: Typically 15-30 minutes depending on data size

### Manual Scrub

If needed to run scrub outside the monthly schedule:

```bash
# Start scrub (runs in background)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs scrub start /mnt/storage"

# Monitor progress
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "watch -n 10 sudo btrfs scrub status /mnt/storage"

# Cancel running scrub (if needed)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs scrub cancel /mnt/storage"
```

**When to run manual scrub**:

- After power loss or unclean shutdown
- After hardware changes or disk replacement
- Before major filesystem operations (balance, resize)
- If SMART errors detected on drives

### Automated Scrub Schedule

Scrubs run automatically on the 1st of each month at 2 AM via systemd timer.

**Check timer status**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl status btrfs-scrub.timer"
```

**View scrub logs**:

```bash
# Last scrub execution
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl -u btrfs-scrub.service -n 50"

# All scrub history
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl -u btrfs-scrub.service --since '30 days ago'"
```

## Balance Operations

Balance operations redistribute data across drives to maintain optimal allocation and reclaim free space. Important
after large deletions or when filesystem becomes unbalanced.

### Check Balance Status

```bash
# Show current allocation
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs filesystem usage /mnt/storage"
```

**Key metrics**:

```text
Overall:
    Device size:           2.00TiB
    Device allocated:      460.00GiB
    Device unallocated:    1.54TiB
    Used:                  450.00GiB
    Free (estimated):      550.00GiB
```

**Balance needed if**:

- Unallocated space is low (< 20GB)
- Device allocated is much higher than used (> 50GB difference)
- Free space warnings despite low disk usage

### Manual Balance

```bash
# Start balance (runs in background)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs balance start -dusage=50 -musage=50 /mnt/storage"

# Monitor progress
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs balance status /mnt/storage"

# Cancel running balance (if needed)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs balance cancel /mnt/storage"
```

**Balance options explained**:

- `-dusage=50`: Rebalance data chunks that are < 50% full
- `-musage=50`: Rebalance metadata chunks that are < 50% full
- Higher values = more aggressive rebalancing (50-75 is typical)

**Balance duration**: 30 minutes to 2 hours depending on data size.

### Automated Balance Schedule

Balances run automatically quarterly (1st of January, April, July, October) at 3 AM.

**Check timer status**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl status btrfs-balance.timer"
```

**View balance logs**:

```bash
# Last balance execution
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl -u btrfs-balance.service -n 50"
```

### Emergency Full Balance

Only needed in rare cases (filesystem corruption recovery, severe fragmentation):

```bash
# WARNING: Can take 4-8 hours and causes high I/O load
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs balance start /mnt/storage"
```

**Use with caution** - prefer targeted balances with usage filters.

## Snapshot Management

Automated snapshots provide point-in-time recovery for the NFS data directory. Snapshots are read-only and
space-efficient (only changed blocks consume space).

### Snapshot Overview

**Snapshot location**: `/mnt/storage/.snapshots/`

**Retention policy** (configured in `btrfs_snapshots` role):

- Hourly snapshots: Last 24 hours
- Daily snapshots: Last 7 days
- Weekly snapshots: Last 4 weeks
- Monthly snapshots: Last 6 months

**Total snapshots**: ~150-200 depending on retention

### View Snapshots

```bash
# List all snapshots
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ls -lh /mnt/storage/.snapshots/"

# Count snapshots by type
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ls /mnt/storage/.snapshots/ | grep -E 'hourly|daily|weekly|monthly' | sort | uniq -c"

# Show snapshot sizes (space usage)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs subvolume list -s /mnt/storage"
```

### Snapshot Space Usage

```bash
# Show space used by snapshots vs active data
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs filesystem du -s /mnt/storage/.snapshots/*"
```

**Interpreting results**:

- Snapshots typically use 5-15% of active data size
- High snapshot usage (> 30%) indicates frequent file changes
- Zero snapshot usage for old snapshots is normal (no unique data)

### Manual Snapshot Creation

Create one-time snapshots before major changes:

```bash
# Create named snapshot
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs subvolume snapshot -r /mnt/storage/pool/data /mnt/storage/.snapshots/manual-$(date +%Y%m%d-%H%M%S)"

# List recent snapshots
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ls -lt /mnt/storage/.snapshots/ | head -10"
```

### Snapshot Cleanup

Automated cleanup runs daily at 3 AM via `btrfs-snapshot-cleanup.timer`.

**Manual cleanup** (remove expired snapshots):

```bash
# Run cleanup script manually
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo /usr/local/bin/btrfs-snapshot-cleanup.sh"

# View cleanup logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl -u btrfs-snapshot-cleanup.service -n 50"
```

### Delete Specific Snapshot

```bash
# List snapshots
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ls /mnt/storage/.snapshots/"

# Delete specific snapshot
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs subvolume delete /mnt/storage/.snapshots/manual-20241201-120000"
```

**Warning**: Deleting snapshots is irreversible. Only delete snapshots you no longer need for recovery.

## Disk Health Monitoring

### SMART Health Check

SMART (Self-Monitoring, Analysis, and Reporting Technology) monitors disk health.

```bash
# Check SMART status for both drives
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo smartctl -H /dev/sda && sudo smartctl -H /dev/sdb"
```

**Expected output**:

```text
SMART overall-health self-assessment test result: PASSED
```

**If FAILED**: Disk replacement needed - see "Disk Replacement" section.

### Detailed SMART Information

```bash
# View detailed SMART data
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo smartctl -a /dev/sda"

# Key attributes to monitor:
# - Reallocated_Sector_Ct (should be 0 or very low)
# - Current_Pending_Sector (should be 0)
# - Offline_Uncorrectable (should be 0)
# - Temperature_Celsius (should be < 50°C)
```

### RAID Status Check

```bash
# Show RAID configuration and device status
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs filesystem show /mnt/storage"
```

**Expected output**:

```text
Label: none  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Total devices 2 FS bytes used XXX.XXGiB
    devid    1 size 931.51GiB used XXX.XXGiB path /dev/sda
    devid    2 size 931.51GiB used XXX.XXGiB path /dev/sdb
```

**Both devices should show**:

- Same total size
- Similar used values (within 10% for RAID1)
- No "missing" or "degraded" warnings

## Cleanup Procedures

### Free Up Disk Space

When disk usage is high (> 80%):

**1. Delete old snapshots manually** (if automated retention is too aggressive):

```bash
# Delete specific snapshot ranges
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs subvolume delete /mnt/storage/.snapshots/hourly-2024*"
```

**2. Run balance to reclaim space**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs balance start -dusage=75 /mnt/storage"
```

**3. Find and remove large files**:

```bash
# Find largest files in NFS data
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo find /mnt/storage/pool/data -type f -size +1G -exec ls -lh {} \; | sort -k5 -hr | head -20"
```

### Defragmentation

Btrfs can become fragmented over time, especially with large files that are frequently modified.

**When to defragment**:

- Large database files (Jellyfin, Sonarr)
- VM disk images
- Video files that have been modified
- Noticeable performance degradation

**Defragment specific directory**:

```bash
# Defragment media directory
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs filesystem defragment -r /mnt/storage/pool/data/media"
```

**Warning**: Defragmenting breaks file sharing between snapshots, increasing space usage. Use sparingly.

### Remove Deleted Files from Snapshots

Deleted files can still consume space if present in snapshots. Options:

**Option 1**: Wait for snapshots to age out naturally (recommended)
**Option 2**: Delete snapshots containing the deleted files
**Option 3**: Run balance to optimize space allocation

## Backup and Recovery

### Filesystem Backup

Btrfs snapshots provide point-in-time recovery, but are NOT a substitute for off-site backups.

**Recommended backup strategy**:

- Snapshots: Local recovery (accidental deletion, ransomware)
- Off-site backups: Disaster recovery (hardware failure, site loss)

**Using `btrfs send` for incremental backups**:

```bash
# Create initial backup
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs send /mnt/storage/.snapshots/daily-$(date +%Y%m%d)" | \
  pv | gzip > ~/backups/nas-initial-$(date +%Y%m%d).btrfs.gz

# Incremental backup (subsequent backups)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs send -p /mnt/storage/.snapshots/daily-20241201 /mnt/storage/.snapshots/daily-20241202" | \
  pv | gzip > ~/backups/nas-increment-$(date +%Y%m%d).btrfs.gz
```

### Restore from Snapshot

**Restore entire data directory** (emergency recovery):

```bash
# 1. Stop NFS clients (to prevent writes during restore)
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net "sudo systemctl stop jellyfin"
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net "docker compose down"

# 2. SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# 3. Delete current data (CAUTION!)
sudo mv /mnt/storage/pool/data /mnt/storage/pool/data.corrupted

# 4. Restore from snapshot (creates writable copy)
sudo btrfs subvolume snapshot /mnt/storage/.snapshots/daily-20241201 /mnt/storage/pool/data

# 5. Fix ownership
sudo chown -R 3000:3000 /mnt/storage/pool/data

# 6. Restart NFS clients
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net "sudo systemctl start jellyfin"
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net "docker compose up -d"
```

**Restore individual files**:

```bash
# Access snapshot directly (read-only)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ls /mnt/storage/.snapshots/daily-20241201/media/"

# Copy specific file from snapshot
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo cp /mnt/storage/.snapshots/daily-20241201/media/Movies/example.mkv \
   /mnt/storage/pool/data/media/Movies/"
```

## Troubleshooting

### Disk Errors Detected

**Symptom**: `btrfs device stats` shows non-zero error counts

**Solution**:

```bash
# 1. Run scrub to identify bad blocks
sudo btrfs scrub start /mnt/storage

# 2. Monitor scrub for errors
sudo btrfs scrub status -d /mnt/storage

# 3. If errors found, check SMART
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/sdb

# 4. If SMART shows failures, replace disk (see Disk Replacement)
```

### Filesystem Full (ENOSPC)

**Symptom**: "No space left on device" despite available space

**Cause**: Btrfs allocates space in chunks; may run out of allocatable chunks before data fills

**Solution**:

```bash
# 1. Check allocation
sudo btrfs filesystem usage /mnt/storage

# 2. Run balance to free chunks
sudo btrfs balance start -dusage=75 -musage=50 /mnt/storage

# 3. Verify space available
df -h /mnt/storage
```

### Snapshot Creation Failing

**Symptom**: Automated snapshots not created

**Solution**:

```bash
# 1. Check timer status
systemctl status btrfs-snapshot@hourly.timer

# 2. View service logs
journalctl -u btrfs-snapshot@hourly.service -n 50

# 3. Test manual snapshot
sudo btrfs subvolume snapshot -r /mnt/storage/pool/data /mnt/storage/.snapshots/test-$(date +%Y%m%d)

# 4. If successful, restart timer
sudo systemctl restart btrfs-snapshot@hourly.timer
```

### Slow Performance

**Symptom**: NFS read/write performance degraded

**Possible causes and solutions**:

**1. Fragmentation**:

```bash
# Defragment actively used directories
sudo btrfs filesystem defragment -r /mnt/storage/pool/data/torrents
```

**2. Too many snapshots**:

```bash
# Reduce retention (edit /etc/systemd/system/btrfs-snapshot-cleanup.service)
# Or delete old snapshots manually
sudo btrfs subvolume delete /mnt/storage/.snapshots/hourly-2024*
```

**3. Unbalanced filesystem**:

```bash
# Run balance
sudo btrfs balance start -dusage=50 /mnt/storage
```

**4. Disk issues**:

```bash
# Check SMART health
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/sdb

# Check for I/O errors
sudo btrfs device stats /mnt/storage
```

### RAID Degraded

**Symptom**: One disk failed or removed, filesystem in degraded mode

**Solution**:

```bash
# 1. Identify missing device
sudo btrfs filesystem show /mnt/storage

# 2. Add replacement disk (after physical installation)
sudo btrfs device add /dev/sdc /mnt/storage

# 3. Remove failed disk
sudo btrfs device remove /dev/sdb /mnt/storage

# 4. Balance to rebuild RAID
sudo btrfs balance start -dconvert=raid1 -mconvert=raid1 /mnt/storage

# 5. Verify RAID status
sudo btrfs filesystem show /mnt/storage
```

**Note**: RAID rebuild can take 2-8 hours depending on data size.

## Disk Replacement

If a disk fails SMART checks or shows errors:

**Procedure**:

**1. Verify which disk is failing**:

```bash
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/sdb
```

**2. Add new disk** (physically install first):

```bash
# Identify new disk (e.g., /dev/sdc)
lsblk

# Add to filesystem
sudo btrfs device add /dev/sdc /mnt/storage
```

**3. Remove failed disk**:

```bash
# Remove old disk from filesystem
sudo btrfs device remove /dev/sdb /mnt/storage

# This triggers automatic rebalance (can take hours)
```

**4. Monitor rebuild**:

```bash
# Watch rebalance progress
watch -n 10 sudo btrfs balance status /mnt/storage
```

**5. Verify new configuration**:

```bash
# Should show 2 devices (new disk replacing old)
sudo btrfs filesystem show /mnt/storage

# Run scrub to verify data integrity
sudo btrfs scrub start /mnt/storage
```

## Maintenance Scripts

### Automated Scripts

These scripts are deployed during initial setup and run via systemd timers:

**Scrub**: `/usr/local/bin/btrfs-scrub.sh`

- Runs monthly scrub
- Logs results to systemd journal
- Sends notifications on errors (if configured)

**Balance**: `/usr/local/bin/btrfs-balance.sh`

- Runs quarterly balance with usage filters
- Logs progress and completion

**Snapshot cleanup**: `/usr/local/bin/btrfs-snapshot-cleanup.sh`

- Removes snapshots outside retention policy
- Runs daily at 3 AM

**Health check**: `/usr/local/bin/btrfs-health-check.sh`

- Comprehensive health report
- Run manually for diagnostics

### View Script Logs

```bash
# Scrub logs
journalctl -u btrfs-scrub.service --since "7 days ago"

# Balance logs
journalctl -u btrfs-balance.service --since "30 days ago"

# Snapshot cleanup logs
journalctl -u btrfs-snapshot-cleanup.service --since "7 days ago"
```

## Prometheus Monitoring Integration

Btrfs maintenance scripts export metrics to Prometheus via the node_exporter
textfile collector on the NAS VM.

### Exported Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `btrfs_maintenance_last_run_timestamp` | Gauge | Unix timestamp of last maintenance run |
| `btrfs_maintenance_success` | Gauge | 1 if last run succeeded, 0 if failed |
| `btrfs_maintenance_duration_seconds` | Gauge | Duration of last maintenance run |
| `btrfs_maintenance_device_errors_total` | Gauge | Total device errors from `btrfs device stats` |
| `btrfs_maintenance_scrub_errors_total` | Gauge | Total scrub errors detected |

### How It Works

1. Maintenance scripts write `.prom` files to the textfile collector directory
2. node_exporter reads these files and exposes the metrics
3. Prometheus scrapes node_exporter on the NAS VM
4. Alert rules fire through Alertmanager when thresholds are breached

### Verifying Metrics

```bash
# Check metrics are being exported
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "ls -la /var/lib/node_exporter/textfile_collector/"

# Query metrics in Prometheus
# http://monitoring.discus-moth.ts.net:9090
# Query: btrfs_maintenance_success
```

See [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md) for
related alert rules.

## Best Practices

### DO

- Monitor disk space weekly (keep below 80% usage)
- Review scrub results monthly
- Verify snapshots are being created regularly
- Run manual scrub before major filesystem operations
- Check SMART health quarterly
- Balance filesystem after large deletions
- Create manual snapshots before major changes

### DON'T

- Delete snapshots aggressively (breaks point-in-time recovery)
- Run full balance unless necessary (use usage filters)
- Ignore SMART warnings (replace disks proactively)
- Defragment entire filesystem (breaks snapshot sharing)
- Disable automated maintenance timers
- Fill filesystem above 90% (can cause allocation issues)

## Maintenance Schedule Summary

### Weekly

- [ ] Check disk usage (`btrfs filesystem usage /mnt/storage`)
- [ ] Verify snapshots exist (`ls /mnt/storage/.snapshots/`)
- [ ] Quick SMART check (`smartctl -H /dev/sda /dev/sdb`)

### Monthly

- [ ] Review scrub results (`btrfs scrub status`)
- [ ] Check RAID status (`btrfs filesystem show`)
- [ ] Review snapshot space usage (`btrfs filesystem du`)

### Quarterly

- [ ] Review balance results (`journalctl -u btrfs-balance.service`)
- [ ] Comprehensive SMART review (`smartctl -a /dev/sda /dev/sdb`)
- [ ] Test snapshot restore procedure

### Annually

- [ ] Review retention policies (adjust if needed)
- [ ] Plan disk replacement schedule (based on SMART data)
- [ ] Review backup strategy

## Reference

### Related Documentation

- [NAS Troubleshooting](../troubleshooting/nas-nfs.md) - NFS and storage issues
- [Btrfs Optimization Reference](../reference/btrfs-optimization.md) - Filesystem tuning and snapshots
- [Service Updates](updates.md) - General update procedures

### External Resources

- [Btrfs Wiki](https://btrfs.wiki.kernel.org/) - Official documentation
- [Btrfs Scrub Documentation](https://btrfs.wiki.kernel.org/index.php/Manpage/btrfs-scrub)
- [Btrfs Balance Guide](https://btrfs.wiki.kernel.org/index.php/Balance_Filters)
- [SMART Monitoring Guide](https://www.smartmontools.org/wiki/TocDoc)

## Summary

**Key Maintenance Tasks**:

- **Automated**: Scrubs (monthly), balances (quarterly), snapshot cleanup (daily)
- **Manual**: Weekly health checks, monthly SMART reviews, quarterly retention reviews

**Key Commands**:

```bash
# Health check
sudo btrfs filesystem show /mnt/storage
sudo btrfs filesystem usage /mnt/storage
sudo btrfs device stats /mnt/storage

# Scrub
sudo btrfs scrub start /mnt/storage
sudo btrfs scrub status /mnt/storage

# Balance
sudo btrfs balance start -dusage=50 /mnt/storage

# Snapshots
ls /mnt/storage/.snapshots/
sudo btrfs subvolume list -s /mnt/storage

# SMART
sudo smartctl -H /dev/sda /dev/sdb
```

**Best Practices**:

- Monitor regularly, intervene rarely
- Let automated tasks handle routine maintenance
- Manual intervention only for issues or major changes
- Replace disks proactively based on SMART data
- Maintain off-site backups for disaster recovery

Your Btrfs filesystem stays healthy and reliable!
