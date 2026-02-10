# Jellyfin Maintenance

Maintenance procedures for the Jellyfin media server.

> **IMPORTANT**: Jellyfin runs as a **native systemd service** on the Jellyfin VM (192.168.0.12).
> Use `sudo systemctl` commands, NOT `systemctl --user`. Jellyfin is NOT containerized.

## Overview

- **VM**: jellyfin (VMID 400, 192.168.0.12)
- **Ports**: 8096 (HTTP), 8920 (HTTPS), 7359 (Discovery)
- **Config Path**: `/etc/jellyfin/` and `/var/lib/jellyfin/`
- **Media Path**: `/mnt/data/media/` (NFS mount)
- **Logs**: `/var/log/jellyfin/` and `journalctl -u jellyfin`

## Routine Maintenance

### Daily Checks

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Check service status
sudo systemctl status jellyfin

# Quick health check
curl -s http://localhost:8096/System/Info/Public | jq '.Version'

# Check for active streams
curl -s http://localhost:8096/Sessions -H "X-Emby-Token: YOUR_API_KEY" | jq length
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /mnt/data
   du -sh /mnt/data/media/*
   du -sh /var/lib/jellyfin/
   ```

2. **Review logs for errors**:

   ```bash
   sudo journalctl -u jellyfin --since "1 week ago" | grep -i error | tail -20
   ```

3. **Check transcoding temp directory**:

   ```bash
   # Default location
   du -sh /var/lib/jellyfin/transcodes/

   # Clean if needed (only when no active transcodes)
   sudo rm -rf /var/lib/jellyfin/transcodes/*
   ```

### Monthly Maintenance

1. **Update Jellyfin**
2. **Clean up metadata cache**
3. **Verify backup integrity**
4. **Review user accounts and permissions**
5. **Check plugin updates**

## Service Updates

### Update Jellyfin

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Update package lists
sudo apt update

# Check available version
apt-cache policy jellyfin

# Upgrade Jellyfin
sudo apt upgrade jellyfin jellyfin-server jellyfin-web

# Verify service restarted
sudo systemctl status jellyfin

# Check version in logs
sudo journalctl -u jellyfin -n 50 | grep -i version
```

### Update via Ansible

```bash
# From ansible controller
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml
```

### Rollback After Failed Update

```bash
# Check available versions
apt-cache madison jellyfin

# Install specific version
sudo apt install jellyfin=<version> jellyfin-server=<version> jellyfin-web=<version>

# Hold package to prevent auto-upgrade
sudo apt-mark hold jellyfin jellyfin-server jellyfin-web

# Later, unhold to allow updates
sudo apt-mark unhold jellyfin jellyfin-server jellyfin-web
```

## Library Management

### Trigger Library Scan

**Via Web UI**:

1. Dashboard → Libraries
2. Select library → Scan Library Files

**Via API**:

```bash
# Scan all libraries
curl -X POST "http://localhost:8096/Library/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"

# Scan specific library (get library ID first)
curl "http://localhost:8096/Library/VirtualFolders" \
  -H "X-Emby-Token: YOUR_API_KEY" | jq '.[].ItemId'

curl -X POST "http://localhost:8096/Items/<LIBRARY_ID>/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"
```

### Clear Metadata Cache

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Remove metadata cache
sudo rm -rf /var/lib/jellyfin/metadata/

# Start Jellyfin (will rebuild on next scan)
sudo systemctl start jellyfin
```

### Fix Missing Metadata

1. Dashboard → Libraries → Select Library
2. Click "Scan Library Files" with "Replace all metadata" option
3. Or for specific items: Right-click → Refresh Metadata → Replace all metadata

## Database Maintenance

### Database Location

```text
/var/lib/jellyfin/data/
├── library.db           # Main library database
├── jellyfin.db          # User data, playback state
└── *.db-shm, *.db-wal   # SQLite working files
```

### Backup Database

```bash
# Stop Jellyfin for consistent backup
sudo systemctl stop jellyfin

# Backup databases
sudo cp /var/lib/jellyfin/data/library.db /var/lib/jellyfin/data/library.db.bak
sudo cp /var/lib/jellyfin/data/jellyfin.db /var/lib/jellyfin/data/jellyfin.db.bak

# Start Jellyfin
sudo systemctl start jellyfin
```

### Optimize Database

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Vacuum and reindex (reduces file size, improves performance)
sudo sqlite3 /var/lib/jellyfin/data/library.db "VACUUM;"
sudo sqlite3 /var/lib/jellyfin/data/library.db "REINDEX;"

sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db "VACUUM;"
sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db "REINDEX;"

# Start Jellyfin
sudo systemctl start jellyfin
```

### Check Database Integrity

```bash
# Check for corruption
sudo sqlite3 /var/lib/jellyfin/data/library.db "PRAGMA integrity_check;"
sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db "PRAGMA integrity_check;"
```

## Transcoding Maintenance

### Monitor Active Transcodes

```bash
# Check transcoding directory
ls -la /var/lib/jellyfin/transcodes/

# Watch for transcoding processes
watch -n 2 'ps aux | grep -E "ffmpeg|jellyfin" | grep -v grep'

# Check GPU utilization (if using hardware transcoding)
intel_gpu_top  # For Intel QSV
```

### Clear Transcoding Cache

```bash
# Only when no active streams
sudo rm -rf /var/lib/jellyfin/transcodes/*
```

### Verify Hardware Transcoding

```bash
# Check GPU device permissions
ls -la /dev/dri/

# Verify Jellyfin user can access GPU
sudo -u jellyfin ls -la /dev/dri/

# Check for QSV support
vainfo 2>&1 | grep -E "Driver|Profile"

# Monitor during playback
sudo journalctl -u jellyfin -f | grep -i "transcode\|qsv\|hardware"
```

### Fix Hardware Transcoding Issues

```bash
# Add jellyfin user to render group
sudo usermod -aG render jellyfin

# Restart service
sudo systemctl restart jellyfin

# Verify group membership
groups jellyfin
```

## Plugin Management

### Update Plugins

1. Dashboard → Plugins → Installed
2. Check for available updates
3. Install updates
4. Restart Jellyfin when prompted

### Remove Broken Plugin

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# List installed plugins
ls -la /var/lib/jellyfin/plugins/

# Remove problematic plugin
sudo rm -rf /var/lib/jellyfin/plugins/<PluginName>/

# Start Jellyfin
sudo systemctl start jellyfin
```

### Clear Plugin Cache

```bash
sudo systemctl stop jellyfin
sudo rm -rf /var/lib/jellyfin/plugins/cache/
sudo systemctl start jellyfin
```

## Backup Procedures

### Full Backup

```bash
#!/bin/bash
# Save as ~/backup-jellyfin.sh

BACKUP_DIR="/mnt/data/backups/jellyfin"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop Jellyfin for consistent backup
sudo systemctl stop jellyfin

# Backup configuration
sudo tar -czf "$BACKUP_DIR/jellyfin-config-${DATE}.tar.gz" /etc/jellyfin/

# Backup data (includes database, plugins, metadata)
sudo tar -czf "$BACKUP_DIR/jellyfin-data-${DATE}.tar.gz" /var/lib/jellyfin/

# Start Jellyfin
sudo systemctl start jellyfin

# Set permissions
sudo chown ansible:ansible "$BACKUP_DIR"/*.tar.gz

echo "Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"/*${DATE}*
```

### Database-Only Backup (Faster)

```bash
# Quick backup without stopping service
sqlite3 /var/lib/jellyfin/data/library.db ".backup '/tmp/library-backup.db'"
sqlite3 /var/lib/jellyfin/data/jellyfin.db ".backup '/tmp/jellyfin-backup.db'"

# Move to backup location
mv /tmp/*-backup.db /mnt/data/backups/jellyfin/
```

### Restore from Backup

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Restore configuration
sudo rm -rf /etc/jellyfin
sudo tar -xzf /mnt/data/backups/jellyfin/jellyfin-config-YYYYMMDD.tar.gz -C /

# Restore data
sudo rm -rf /var/lib/jellyfin
sudo tar -xzf /mnt/data/backups/jellyfin/jellyfin-data-YYYYMMDD.tar.gz -C /

# Fix permissions
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
sudo chown -R jellyfin:jellyfin /etc/jellyfin

# Start Jellyfin
sudo systemctl start jellyfin
```

### Schedule Automatic Backups

```bash
# Add to root crontab
sudo crontab -e

# Weekly backup at 4 AM Sunday
0 4 * * 0 /home/ansible/backup-jellyfin.sh >> /var/log/jellyfin-backup.log 2>&1
```

## Log Management

### View Logs

```bash
# Systemd journal logs
sudo journalctl -u jellyfin -f           # Follow live
sudo journalctl -u jellyfin -n 100       # Last 100 lines
sudo journalctl -u jellyfin --since "1 hour ago"

# Application logs
ls -la /var/log/jellyfin/
tail -f /var/log/jellyfin/log_*.log
```

### Clean Old Logs

```bash
# Remove logs older than 30 days
sudo find /var/log/jellyfin/ -name "*.log" -mtime +30 -delete

# Check log directory size
du -sh /var/log/jellyfin/
```

### Adjust Log Level

Edit `/etc/jellyfin/logging.default.json`:

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Warning"
    }
  }
}
```

Then restart: `sudo systemctl restart jellyfin`

## NFS Mount Maintenance

### Verify NFS Mount

```bash
# Check mount status
df -h /mnt/data
mount | grep nfs

# Test read access
ls /mnt/data/media/movies/ | head -5

# Test write access (if applicable)
touch /mnt/data/test && rm /mnt/data/test
```

### Remount NFS

```bash
# If mount is stale
sudo umount -l /mnt/data
sudo mount /mnt/data

# Or remount
sudo mount -o remount /mnt/data
```

### Check NFS Performance

```bash
# Test read speed
dd if=/mnt/data/media/movies/somefile.mkv of=/dev/null bs=1M count=1000 status=progress
```

## Performance Monitoring

### Resource Usage

```bash
# Check Jellyfin memory/CPU usage
ps aux | grep jellyfin

# Detailed process info
top -p $(pgrep -f jellyfin-server)

# System-wide resources
htop
```

### Disk I/O

```bash
# Monitor disk I/O
iostat -x 1 5

# Check for I/O wait
vmstat 1 5
```

### Network Throughput

```bash
# Monitor network during streaming
iftop -i eth0

# Check connection count
ss -tn | grep :8096 | wc -l
```

## User Management

### List Users

**Via API**:

```bash
curl -s "http://localhost:8096/Users" \
  -H "X-Emby-Token: YOUR_API_KEY" | jq '.[].Name'
```

### Disable User

```bash
curl -X POST "http://localhost:8096/Users/<USER_ID>/Policy" \
  -H "X-Emby-Token: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"IsDisabled": true}'
```

### Reset User Password

1. Dashboard → Users → Select User
2. Click "Password" tab
3. Set new password or enable "Easy Pin"

## Smart Reboot Feature

The Jellyfin VM includes an automatic reboot feature that safely restarts the system after driver updates (e.g., NVIDIA) without interrupting active viewers.

### How It Works

The smart reboot script checks three conditions before rebooting:

1. **Reboot Required**: Either `/var/run/reboot-required` exists OR NVIDIA driver/library mismatch detected
2. **Time Window**: Current time is within the configured window (default: 3-5 AM)
3. **No Active Playback**: Jellyfin API reports no active streaming sessions

If all conditions pass, the system reboots automatically. Otherwise, it retries on the next timer check (every 30 minutes during the window).

### Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jellyfin_smart_reboot_enabled` | `true` | Enable/disable the feature |
| `jellyfin_smart_reboot_window_start` | `3` | Start hour (24h format) |
| `jellyfin_smart_reboot_window_end` | `5` | End hour (24h format) |
| `jellyfin_smart_reboot_url` | `http://localhost:8096` | Jellyfin API URL |

### Monitoring Smart Reboot

```bash
# Check timer status
sudo systemctl status jellyfin-smart-reboot.timer

# View recent reboot check logs
sudo journalctl -u jellyfin-smart-reboot -n 50

# Check next scheduled run
sudo systemctl list-timers jellyfin-smart-reboot.timer

# Manual test run (won't reboot outside time window)
sudo /usr/local/bin/jellyfin-smart-reboot.sh
```

### Troubleshooting Smart Reboot

**Script not running**:

```bash
# Check timer is enabled
sudo systemctl is-enabled jellyfin-smart-reboot.timer

# Enable if needed
sudo systemctl enable --now jellyfin-smart-reboot.timer
```

**API authentication failures**:

```bash
# Check credentials file exists and has correct permissions
sudo ls -la /etc/jellyfin/smart-reboot-credentials

# Verify API key is set
sudo cat /etc/jellyfin/smart-reboot-credentials

# Test API key manually
curl -s "http://localhost:8096/Sessions" -H "X-Emby-Token: YOUR_API_KEY" | jq length
```

**NVIDIA driver mismatch not detected**:

```bash
# Check NVIDIA driver status
nvidia-smi

# If you see "Driver/library version mismatch", reboot is needed
# The script detects this automatically
```

### Disabling Smart Reboot

To disable the feature via Ansible:

```yaml
# In host_vars/jellyfin.yml
jellyfin_smart_reboot_enabled: false
```

Then run the Jellyfin playbook to apply the change.

---

## Creating a Jellyfin API Key

API keys are required for automation scripts (like smart reboot) to query Jellyfin without user credentials.

### Via Web UI (Recommended)

1. Open Jellyfin Dashboard: `http://jellyfin.discus-moth.ts.net:8096`
2. Navigate to **Dashboard** → **API Keys** (under Advanced)
3. Click **+** (Add API Key)
4. Enter a descriptive name (e.g., "Smart Reboot Script")
5. Click **OK** to create the key
6. Copy the generated API key immediately (it won't be shown again)

### Via Command Line

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Create API key via sqlite (requires admin access)
sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db \
  "INSERT INTO ApiKeys (AccessToken, DateCreated, Name) VALUES ('$(openssl rand -hex 32)', datetime('now'), 'Script Access');"

# Retrieve the key you just created
sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db \
  "SELECT AccessToken FROM ApiKeys WHERE Name='Script Access';"
```

### Testing Your API Key

```bash
# Test public endpoint (no auth required)
curl -s "http://localhost:8096/System/Info/Public" | jq '.Version'

# Test authenticated endpoint
curl -s "http://localhost:8096/Sessions" -H "X-Emby-Token: YOUR_API_KEY" | jq length

# Test user listing (requires admin key)
curl -s "http://localhost:8096/Users" -H "X-Emby-Token: YOUR_API_KEY" | jq '.[].Name'
```

### Storing API Keys Securely

For Ansible-managed scripts, store API keys in the SOPS-encrypted vault:

```yaml
# In group_vars/all.sops.yaml (encrypted)
vault_jellyfin_api_key: "your-api-key-here"
```

The smart reboot script reads the API key from `/etc/jellyfin/smart-reboot-credentials` (mode 0600, root-only), which is populated by Ansible from the vault.

---

## Troubleshooting Common Issues

### Service Won't Start

```bash
# Check status
sudo systemctl status jellyfin

# Check for port conflicts
sudo ss -tlnp | grep -E "8096|8920"

# Check logs for errors
sudo journalctl -u jellyfin -n 100 --no-pager
```

### High Memory Usage

```bash
# Check current usage
ps -o pid,user,%mem,rss,command -p $(pgrep jellyfin-server)

# Restart to clear memory (will interrupt active streams)
sudo systemctl restart jellyfin
```

### Playback Issues

1. Check client compatibility with media format
2. Verify transcoding is working (if needed)
3. Check network throughput
4. Review playback logs in Dashboard → Logs

### Library Not Finding Media

```bash
# Verify NFS mount
ls -la /mnt/data/media/

# Check file permissions
ls -la /mnt/data/media/movies/ | head -10

# Trigger manual scan via API
curl -X POST "http://localhost:8096/Library/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"
```

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Service health check | Daily | Automated via monitoring |
| Log review | Weekly | Check for errors |
| Database backup | Weekly | Before any major changes |
| Transcoding cache cleanup | Weekly | If disk space is limited |
| Database optimization | Monthly | VACUUM and REINDEX |
| Plugin updates | Monthly | Check compatibility |
| Full backup | Weekly | Automated via cron |
| Jellyfin updates | As released | Test in off-peak hours |

## See Also

- [Jellyfin Configuration](../configuration/jellyfin-setup.md)
- [Jellyfin Troubleshooting](../troubleshooting/jellyfin.md)
- [Tdarr Configuration](../configuration/tdarr-setup.md) - Automatic transcoding
- [GPU Passthrough](../configuration/gpu-passthrough.md)
- [Service Endpoints](../configuration/service-endpoints.md)
