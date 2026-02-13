# Tdarr Maintenance

Maintenance procedures for Tdarr automated media transcoding system.

> **IMPORTANT**: Tdarr runs as **rootless Podman containers with Quadlet** on the Jellyfin VM (192.168.30.12).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: jellyfin (VMID 400, 192.168.30.12)
- **Components**: Tdarr Server (8265), Tdarr Node (8267)
- **Config Path**: `/opt/jellyfin/tdarr/`
- **Transcode Cache**: `/mnt/transcode-cache/tdarr` (RAM disk)
- **Quadlet Files**: `~/.config/containers/systemd/tdarr-*.container`

## Routine Maintenance

### Daily Checks

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Check containers are running
podman ps | grep tdarr

# Quick health check via web UI
curl -s http://localhost:8265/api/v2/status | jq '.status'

# Check for failed transcodes
podman logs tdarr-node 2>&1 | grep -i "error\|fail" | tail -10
```

### Weekly Maintenance

1. **Check transcode queue**:
   - Access Web UI: http://jellyfin.discus-moth.ts.net:8265
   - Review failed/stuck jobs in queue
   - Clear old failed jobs if needed

2. **Review disk space**:

   ```bash
   # Check media storage
   df -h /mnt/data

   # Check Tdarr data directory
   du -sh /opt/jellyfin/tdarr/*

   # Check RAM disk cache
   df -h /mnt/transcode-cache
   ```

3. **Check resource usage**:

   ```bash
   podman stats --no-stream tdarr-server tdarr-node
   ```

4. **Review space savings**:
   - Web UI → Statistics tab
   - Track total space saved from transcodes

### Monthly Maintenance

1. **Update containers**
2. **Clean up old logs**
3. **Verify backup integrity**
4. **Review transcode profiles/flows**
5. **Check for stuck files in queue**

## Container Updates

### Update Tdarr Containers

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Pull latest images
podman pull ghcr.io/haveagitgat/tdarr:latest
podman pull ghcr.io/haveagitgat/tdarr_node:latest

# Restart services (server first, then node)
systemctl --user restart tdarr-server
sleep 10
systemctl --user restart tdarr-node

# Verify running
podman ps | grep tdarr
```

### Rollback After Failed Update

```bash
# Stop services
systemctl --user stop tdarr-node tdarr-server

# Find previous images
podman images | grep tdarr

# Tag and use previous version
podman tag <previous-server-id> ghcr.io/haveagitgat/tdarr:rollback
podman tag <previous-node-id> ghcr.io/haveagitgat/tdarr_node:rollback

# Edit Quadlet files to use rollback tags (temporary)
# Then restart
systemctl --user daemon-reload
systemctl --user start tdarr-server tdarr-node
```

## Service Management

### Check Status

```bash
# Systemd service status
systemctl --user status tdarr-server tdarr-node

# Container status
podman ps --filter "name=tdarr"
```

### View Logs

```bash
# Server logs
journalctl --user -u tdarr-server -f
podman logs -f tdarr-server

# Node logs (shows transcode progress)
journalctl --user -u tdarr-node -f
podman logs -f tdarr-node

# Search for errors
podman logs tdarr-node 2>&1 | grep -i error
podman logs tdarr-server 2>&1 | grep -i error
```

### Start/Stop/Restart

```bash
# Stop (node first, then server)
systemctl --user stop tdarr-node
systemctl --user stop tdarr-server

# Start (server first, then node)
systemctl --user start tdarr-server
sleep 10
systemctl --user start tdarr-node

# Restart both
systemctl --user restart tdarr-server && sleep 10 && systemctl --user restart tdarr-node
```

### Pause/Resume Queue

**Via Web UI**:

1. Access http://jellyfin.discus-moth.ts.net:8265
2. Click pause/resume button in header

**Via API**:

```bash
# Pause queue
curl -X POST "http://localhost:8265/api/v2/pause-queue"

# Resume queue
curl -X POST "http://localhost:8265/api/v2/resume-queue"
```

## Transcode Queue Management

### Clear Failed Jobs

**Via Web UI**:

1. Go to Queue tab
2. Filter by "Failed"
3. Select all → Remove from queue

### Requeue Failed Jobs

**Via Web UI**:

1. Go to Queue tab
2. Filter by "Failed"
3. Select all → Requeue

### Force Rescan Library

**Via Web UI**:

1. Go to Libraries tab
2. Select library
3. Click "Scan" button

**Via command line**:

```bash
# Remove Tdarr's library cache to force full rescan
# This clears what Tdarr knows about the library
rm -rf /opt/jellyfin/tdarr/server/Tdarr/Library/*

# Restart server
systemctl --user restart tdarr-server
```

## Cache and Temp Management

### RAM Disk Cache

The transcode cache uses a RAM disk to prevent SSD wear:

```bash
# Check RAM disk usage
df -h /mnt/transcode-cache

# View current cache contents
ls -la /mnt/transcode-cache/tdarr/

# Clear cache (only when no active transcodes!)
rm -rf /mnt/transcode-cache/tdarr/*
```

### Clean Stuck Temp Files

If transcodes fail, temp files may remain:

```bash
# Check for old temp files
find /mnt/transcode-cache/tdarr -type f -mmin +60 -ls

# Remove old temp files (older than 1 hour)
find /mnt/transcode-cache/tdarr -type f -mmin +60 -delete
```

### Server Data Cleanup

```bash
# Check Tdarr data size
du -sh /opt/jellyfin/tdarr/server/

# Clean old logs
find /opt/jellyfin/tdarr/logs -name "*.log" -mtime +30 -delete

# Check database size
ls -lh /opt/jellyfin/tdarr/server/Tdarr/DB2/
```

## Resource Monitoring

### Memory Usage

Tdarr Node requires significant memory for 4K transcoding:

```bash
# Check container memory usage
podman stats --no-stream tdarr-server tdarr-node

# Check VM memory
free -h

# Expected during 4K transcode:
# - tdarr-server: ~512MB - 1GB
# - tdarr-node: ~2-4GB (can spike to 6GB for 4K HDR)
```

### CPU Usage

```bash
# Monitor CPU during transcode
top -p $(pgrep -d',' -f 'tdarr\|ffmpeg')

# Or use htop for better visualization
htop
```

### GPU Usage (if NVENC enabled)

```bash
# Monitor GPU utilization
nvidia-smi -l 1

# Check NVENC sessions
nvidia-smi -q | grep -A 5 "Encoder"
```

### Disk I/O

```bash
# Monitor disk I/O during transcodes
iostat -x 1 5

# Check if RAM disk is being used (should show minimal I/O on SSD)
iotop -o
```

## Backup Procedures

### Backup Configuration

```bash
#!/bin/bash
# Save as ~/backup-tdarr.sh

BACKUP_DIR="/mnt/data/backups/tdarr"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop services for consistent backup
systemctl --user stop tdarr-node tdarr-server

# Backup configuration and server data
tar -czf "$BACKUP_DIR/tdarr-${DATE}.tar.gz" \
  -C /opt/jellyfin/tdarr \
  configs server

# Start services
systemctl --user start tdarr-server
sleep 10
systemctl --user start tdarr-node

echo "Backup complete: $BACKUP_DIR/tdarr-${DATE}.tar.gz"
```

### What to Backup

| Path | Purpose | Include |
|------|---------|---------|
| `/opt/jellyfin/tdarr/configs` | Container configs | ✅ Yes |
| `/opt/jellyfin/tdarr/server` | Database, flows, settings | ✅ Yes |
| `/opt/jellyfin/tdarr/logs` | Log files | ❌ No (regenerated) |
| `/mnt/transcode-cache/tdarr` | Temp cache | ❌ No (RAM disk) |

### Restore from Backup

```bash
# Stop services
systemctl --user stop tdarr-node tdarr-server

# Remove current data
rm -rf /opt/jellyfin/tdarr/configs /opt/jellyfin/tdarr/server

# Restore from backup
tar -xzf /mnt/data/backups/tdarr/tdarr-YYYYMMDD.tar.gz -C /opt/jellyfin/tdarr/

# Fix permissions
sudo chown -R 1000:1000 /opt/jellyfin/tdarr

# Start services
systemctl --user start tdarr-server
sleep 10
systemctl --user start tdarr-node
```

## Database Maintenance

### Database Location

```text
/opt/jellyfin/tdarr/server/Tdarr/
├── DB2/                    # Main database (LevelDB)
├── Library/                # Library scan cache
├── Plugins/                # Installed plugins
└── FlowPlugins/            # Flow definitions
```

### Compact Database

Tdarr uses LevelDB which doesn't need manual optimization. However, you can rebuild if needed:

```bash
# Stop services
systemctl --user stop tdarr-node tdarr-server

# Backup first
cp -r /opt/jellyfin/tdarr/server/Tdarr/DB2 /opt/jellyfin/tdarr/server/Tdarr/DB2.bak

# Clear library cache (forces rescan, doesn't lose settings)
rm -rf /opt/jellyfin/tdarr/server/Tdarr/Library/*

# Start services
systemctl --user start tdarr-server
sleep 10
systemctl --user start tdarr-node
```

## Flow/Plugin Maintenance

### Update Plugins

1. Access Web UI → Plugins tab
2. Check for available updates
3. Install updates
4. Test flows after updates

### Export Flow Configuration

1. Web UI → Flows tab
2. Select flow → Export
3. Save JSON backup

### Import Flow Configuration

1. Web UI → Flows tab
2. Click Import
3. Select JSON file
4. Verify connections

## Performance Tuning

### Adjust Concurrent Transcodes

**Via Web UI**:

1. Go to Options → Transcode Options
2. Adjust "Concurrent Transcodes" (start with 1)
3. Monitor resources before increasing

### Adjust Node Workers

**Via Web UI**:

1. Go to Nodes → JellyfinNode
2. Adjust GPU/CPU workers:
   - GPU Workers: 2 (NVENC limit without patch)
   - CPU Workers: 0 (GPU handles encoding)
   - Health Check CPU: 1

### Optimize Transcode Speed

For faster transcodes (less compression):

- Change preset: `medium` → `fast`
- Increase CRF: `23` → `25`
- Disable audio transcode: Use `copy`

For better compression (slower):

- Change preset: `medium` → `slow`
- Decrease CRF: `23` → `21`

## Troubleshooting Common Issues

### Containers Not Starting

```bash
# Check service status
systemctl --user status tdarr-server tdarr-node

# Check logs
journalctl --user -u tdarr-server -n 50
journalctl --user -u tdarr-node -n 50

# Check Quadlet files
cat ~/.config/containers/systemd/tdarr-server.container
cat ~/.config/containers/systemd/tdarr-node.container

# Reload systemd and restart
systemctl --user daemon-reload
systemctl --user restart tdarr-server tdarr-node
```

### Node Not Connecting to Server

```bash
# Check server is running
curl -s http://localhost:8265/api/v2/status

# Check node logs for connection errors
podman logs tdarr-node | grep -i "connect\|error"

# Verify server URL in node config
grep -i "server" ~/.config/containers/systemd/tdarr-node.container
```

### Transcodes Failing

```bash
# Check node logs for specific errors
podman logs tdarr-node 2>&1 | grep -A 5 "error\|fail"

# Check available disk space
df -h /mnt/transcode-cache
df -h /mnt/data

# Check memory (OOM kills)
dmesg | grep -i "oom\|kill" | tail -10
journalctl --user -u tdarr-node | grep -i "oom\|memory"
```

### Permission Issues

```bash
# Check Tdarr directory permissions
ls -la /opt/jellyfin/tdarr/

# Fix permissions (UID 1000 is the container user)
sudo chown -R 1000:1000 /opt/jellyfin/tdarr

# Check NFS mount permissions
ls -la /mnt/data/media/
```

### OOM Kills During 4K Transcode

```bash
# Check if OOM occurred
dmesg | grep -i oom | tail -5

# Verify memory limit is 8GB
podman inspect tdarr-node --format '{{.HostConfig.Memory}}'
# Should show: 8589934592 (8GB)

# If less, update Quadlet file and restart
```

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Check queue status | Daily | Via Web UI |
| Review failed jobs | Daily | Clear or requeue |
| Check disk space | Weekly | RAM disk and media storage |
| Clean temp files | Weekly | If transcodes failed |
| Container updates | Monthly | Test before production |
| Backup configuration | Weekly | Before updates |
| Review space savings | Monthly | Statistics tab |
| Clean old logs | Monthly | Logs older than 30 days |

## See Also

- [Tdarr Configuration](../configuration/tdarr-setup.md)
- [Tdarr Flow Configuration](../configuration/tdarr-flow-configuration.md)
- [Tdarr Troubleshooting](../troubleshooting/tdarr.md)
- [GPU Passthrough](../configuration/gpu-passthrough.md)
- [Jellyfin Maintenance](jellyfin-maintenance.md)
