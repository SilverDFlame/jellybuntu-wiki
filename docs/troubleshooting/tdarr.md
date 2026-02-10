# Tdarr Troubleshooting Guide

> **IMPORTANT**: Tdarr runs as a **rootless Podman container with Quadlet** on the Jellyfin VM (192.168.0.12).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Quick Diagnostics

### Check Service Status

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Check service status
systemctl --user status tdarr-server tdarr-node

# View logs
journalctl --user -u tdarr-server -f
journalctl --user -u tdarr-node -f

# Check containers are running
podman ps | grep tdarr
```

### Check Web UI Access

```bash
# Test UI is accessible
curl -I http://jellyfin.discus-moth.ts.net:8265

# Expected: HTTP/1.1 200 OK
```

### Check Memory Usage

```bash
# View current memory usage
podman stats --no-stream tdarr-server tdarr-node

# Expected:
# tdarr-server: < 1GB
# tdarr-node: < 2GB (during transcode)
```

### View Logs

```bash
# Server logs
journalctl --user -u tdarr-server -n 50

# Node logs
journalctl --user -u tdarr-node -n 50

# Follow logs in real-time
journalctl --user -u tdarr-node -f
```

## Common Issues

### Issue: Web UI Not Accessible

**Symptoms**:

- Cannot connect to http://jellyfin.discus-moth.ts.net:8265
- Browser shows "Connection refused" or timeout

**Causes & Solutions**:

1. **Container Not Running**:

   ```bash
   systemctl --user status tdarr-server

   # If not running, check why:
   journalctl --user -u tdarr-server -n 100

   # Restart container:
   systemctl --user restart tdarr-server
   ```

2. **Firewall Blocking Port 8265**:

   ```bash
   # Check UFW rules
   ssh ansible@jellyfin.discus-moth.ts.net "sudo ufw status | grep 8265"

   # Expected: 8265/tcp ALLOW Anywhere

   # If missing, re-run playbook:
   ./bin/runtime/ansible-run.sh playbooks/services/tdarr.yml
   ```

3. **Wrong Network Mode**:

   ```bash
   # Verify network_mode: host is set
   cat ~/.config/containers/systemd/tdarr-server.container | grep Network

   # Expected: network_mode: host
   ```

4. **Tailscale Connection Issue**:

   ```bash
   # Test with IP instead
   curl -I http://192.168.0.12:8265

   # If IP works but hostname doesn't, check Tailscale:
   tailscale status | grep jellyfin
   ```

### Issue: Node Not Connecting to Server

**Symptoms**:

- Web UI shows "No nodes connected"
- Node container running but not processing jobs

**Causes & Solutions**:

1. **Node Started Before Server**:

   ```bash
   # Check container start times
   podman ps --format '{{.Names}}\t{{.Status}}' | grep tdarr

   # Restart node (depends_on should handle this):
   systemctl --user restart tdarr-node
   ```

2. **Incorrect Server IP Configuration**:

   ```bash
   # Check node environment variables
   podman inspect tdarr-node | grep -A 5 Env | grep serverIP"

   # Expected: "serverIP=0.0.0.0"

   # If wrong, fix in compose file and recreate:
   # Edit Quadlet config: ~/.config/containers/systemd/tdarr-node.container
   systemctl --user start tdarr-node
   ```

3. **Port 8266 Communication Issue**:

   ```bash
   # Test server port is listening
   ssh ansible@jellyfin.discus-moth.ts.net "ss -tlnp | grep 8266"

   # Expected: LISTEN on port 8266
   ```

4. **Node ID Mismatch**:

   ```bash
   # Verify node IDs match in both containers
   podman inspect tdarr-server tdarr-node | grep nodeID

   # Expected: Both show "nodeID=JellyfinNode"
   ```

### Issue: Transcode Jobs Failing

**Symptoms**:

- Jobs show "Error" status in queue
- Files remain in queue without processing
- Transcode progress stuck at 0%

**Causes & Solutions**:

1. **Insufficient Memory**:

   ```bash
   # Check if node is hitting memory limit
   podman stats --no-stream tdarr-node | grep MiB

   # If at 2GB limit, consider:
   # - Reduce concurrent transcodes to 1
   # - Process smaller files first
   # - Check for memory leaks in logs
   ```

2. **Codec/FFmpeg Error**:

   ```bash
   # Check node logs for FFmpeg errors
   journalctl --user -u tdarr-node | grep -i error

   # Common errors:
   # - "Encoder 'hevc' not found": Codec not supported
   # - "Invalid data found": Corrupted source file
   # - "Cannot allocate memory": Hit memory limit
   ```

3. **File Permission Issues**:

   ```bash
   # Check NFS mount permissions
   ssh ansible@jellyfin.discus-moth.ts.net "ls -la /mnt/data/media/tv | head"

   # Verify PUID/PGID match NFS user:
   podman inspect tdarr-node | grep -E 'PUID|PGID'"

   # Expected: PUID=1000, PGID=1000 (or your NFS user IDs)

   # If permissions are wrong, fix ownership of Tdarr directories:
   ssh ansible@jellyfin.discus-moth.ts.net "sudo chown -R 1000:1000 /opt/jellyfin/tdarr"

   # Then restart containers:
   systemctl --user restart tdarr-server tdarr-node
   ```

4. **Source File Issues**:

   ```bash
   # Test file integrity on a failed file
   ssh ansible@jellyfin.discus-moth.ts.net "ffprobe /mnt/data/media/tv/ShowName/file.mkv"

   # If errors appear, file may be corrupted
   # Skip this file and report to media source
   ```

5. **Temp Directory Full**:

   ```bash
   # Check temp directory size
   ssh ansible@jellyfin.discus-moth.ts.net "du -sh /opt/jellyfin/tdarr/temp"

   # Check Jellyfin VM disk space
   ssh ansible@jellyfin.discus-moth.ts.net "df -h /opt"

   # Clean temp directory:
   ssh ansible@jellyfin.discus-moth.ts.net "rm -rf /opt/jellyfin/tdarr/temp/*"
   ```

### Issue: High Memory Usage

**Symptoms**:

- Tdarr containers using more memory than expected
- Jellyfin VM memory > 60%
- Memory alerts firing in Grafana

**Causes & Solutions**:

1. **Too Many Concurrent Transcodes**:
   - Web UI > **Options** > **Transcode Options**
   - Reduce "Concurrent Transcodes" from 2 to 1
   - Monitor memory usage for 24 hours

2. **Memory Leak in Tdarr**:

   ```bash
   # Check container uptime
   podman ps --format '{{.Names}}\t{{.Status}}' | grep tdarr

   # If memory grows over time, restart containers:
   systemctl --user restart tdarr-server tdarr-node
   ```

3. **Large File Processing**:

   ```bash
   # Check current transcode job size
   # View in Web UI > Queue > Current Job

   # If processing 4K or very large files:
   # - Increase CRF (faster, less memory)
   # - Use faster preset (less memory intensive)
   # - Process smaller files first
   ```

4. **Container Limits Not Applied**:

   ```bash
   # Verify memory limits are enforced
   podman inspect tdarr-node | grep -A 5 Memory"

   # Expected: "Memory": 2147483648 (2GB in bytes)

   # If 0, limits not applied - re-deploy:
   ./bin/runtime/ansible-run.sh playbooks/services/tdarr.yml
   ```

### Issue: Slow Transcode Speed

**Symptoms**:

- Transcodes take hours for single episode
- Transcode speed < 1x (slower than playback speed)
- Queue not completing in reasonable time

**Causes & Solutions**:

1. **CPU Throttling**:

   ```bash
   # Check CPU governor on Jellyfin VM
   ssh ansible@jellyfin.discus-moth.ts.net "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"

   # Expected: "performance" (set by Jellyfin playbook)

   # If "powersave", Jellyfin playbook may not have run properly
   ```

2. **Too Low Priority**:

   ```bash
   # Check process nice value
   podman top tdarr-node | head

   # If nice value is very high (low priority), consider adjusting
   # Note: Low priority is intentional to avoid impacting Jellyfin
   ```

3. **Inefficient Encoding Settings**:
   - Web UI > **Libraries** > Edit transcode profile
   - Change preset from `slow` to `medium` or `fast`
   - Increase CRF from 23 to 25 (less compression, faster)
   - Use GPU encoding if available (requires additional setup)

4. **Network I/O Bottleneck**:

   ```bash
   # Check NFS mount performance
   ssh ansible@jellyfin.discus-moth.ts.net "dd if=/mnt/data/media/tv/test.mkv of=/dev/null bs=1M count=100"

   # Expected: > 50 MB/s

   # If slow, check:
   # - NAS VM CPU usage
   # - Network congestion
   # - NFS mount options (check /etc/fstab)
   ```

5. **Concurrent Jobs Competing**:
   - Reduce concurrent transcodes to 1
   - Ensure no other heavy processes running on Jellyfin VM

### Issue: Jellyfin Playback Affected

**Symptoms**:

- Jellyfin buffering during Tdarr transcoding
- Playback stuttering or freezing
- Jellyfin UI slow/unresponsive

**Immediate Fix**:

```bash
# Pause Tdarr queue
# Web UI > Queue > Pause

# Or stop Tdarr containers temporarily:
systemctl --user stop tdarr-server tdarr-node
```

**Permanent Solutions**:

1. **Enable Scheduling** (Off-Peak Only):
   - Web UI > **Options** > **Schedule**
   - Enable: **Yes**
   - Active Hours: **02:00 - 06:00** (2 AM to 6 AM)
   - This ensures Tdarr only runs when users unlikely to stream

2. **Reduce Resource Usage**:
   - Decrease concurrent transcodes to 1
   - Lower encoding preset to `faster` or `veryfast`
   - Increase CRF (less CPU intensive)

3. **Increase Jellyfin Priority**:

   ```bash
   # Check Jellyfin service priority (Jellyfin is native systemd, not container)
   sudo systemctl show jellyfin | grep -i nice

   # If not set, consider adding Nice= to the systemd unit
   ```

4. **Monitor During Playback**:

   ```bash
   # Watch resource usage in real-time
   watch -n 2 'podman stats --no-stream'
   ```

### Issue: Files Not Being Scanned

**Symptoms**:

- New media not appearing in Tdarr queue
- Library scan shows 0 files
- Queue remains empty

**Causes & Solutions**:

1. **Library Path Incorrect**:
   - Web UI > **Libraries** > Edit library
   - Verify "Source" path matches container mount:
     - TV Shows: `/media/tv` (NOT `/mnt/data/media/tv`)
     - Movies: `/media/movies`
   - Save and trigger manual scan

2. **NFS Mount Not Available**:

   ```bash
   # Check NFS mount inside container
   podman exec tdarr-server ls -la /media"

   # Expected: tv/ and movies/ directories

   # If empty or errors:
   ssh ansible@jellyfin.discus-moth.ts.net "mount | grep /mnt/data"

   # Re-mount if needed:
   ./bin/runtime/ansible-run.sh playbooks/10-configure-nfs-clients-role.yml
   ```

3. **File Permissions**:

   ```bash
   # Check permissions from inside container
   podman exec tdarr-server ls -la /media/tv | head"

   # Verify PUID/PGID match ownership
   ```

4. **Library Scan Disabled**:
   - Web UI > **Libraries** > Edit library
   - Ensure "Enable Library Scanning" is **Yes**
   - Set scan interval (e.g., daily)
   - Click "Scan" to trigger manual scan

### Issue: Original Files Not Replaced

**Symptoms**:

- Transcoded files created but originals remain
- Storage not being freed
- Duplicate files in media directory

**Causes & Solutions**:

1. **Replace Original Setting Disabled**:
   - Web UI > **Options** > **Transcode Options**
   - Verify "Replace Original" is **Yes**
   - Save settings

2. **File In Use**:

   ```bash
   # Check if Jellyfin has file open
   ssh jellyfin.discus-moth.ts.net "lsof | grep /mnt/data/media/filename.mkv"

   # If in use, Tdarr may wait or fail to replace
   # Stop playback and retry
   ```

3. **Permission Issue**:

   ```bash
   # Verify Tdarr can write to media directory
   podman exec tdarr-server touch /media/tv/test.txt && rm /media/tv/test.txt"

   # If error, check NFS mount permissions and PUID/PGID
   ```

## Performance Optimization

### Optimize Transcode Speed

**Faster Encoding** (sacrifice some quality/compression):

- Preset: `faster` or `veryfast` (instead of `medium`)
- CRF: `25-28` (instead of 23)
- Audio: `copy` (don't transcode audio)
- Remove subtitle processing

**Better Quality** (slower encoding):

- Preset: `slow` or `veryslow` (instead of `medium`)
- CRF: `20-22` (instead of 23)
- Two-pass encoding (enable in plugin settings)

### Optimize Resource Usage

**Reduce Memory Footprint**:

- Concurrent transcodes: **1**
- Close other applications on Jellyfin VM
- Clear temp directory regularly

**Reduce CPU Usage**:

- Lower priority (nice value) - already set by default
- Use faster encoding preset
- Enable scheduling for off-peak hours

### Queue Management

**Prioritize Important Content**:

- Web UI > **Queue** > Drag to reorder
- Process most-watched content first
- Skip rarely-viewed media

**Batch Processing**:

- Process entire library overnight
- Use scheduling to run during off-peak hours
- Monitor first batch before scaling up

**Filter by File Size**:

- Create separate libraries for different file sizes
- Process smaller files first (faster feedback)
- Process 4K content separately with different settings

## Log Locations

### Container Logs

**Docker logs** (stdout/stderr from containers):

```bash
# Server logs
journalctl --user -u tdarr-server -n 100

# Node logs
journalctl --user -u tdarr-node -n 100

# Follow in real-time
journalctl --user -u tdarr-node -f

# Save to file for analysis
journalctl --user -u tdarr-node -n 100 > /tmp/tdarr-node.log
```

### Application Logs

**Tdarr internal logs** (written to volume):

```bash
# List log files
ssh ansible@jellyfin.discus-moth.ts.net "ls -lh /opt/jellyfin/tdarr/logs"

# View server logs
ssh ansible@jellyfin.discus-moth.ts.net "tail -f /opt/jellyfin/tdarr/logs/Tdarr_Server.log"

# View node logs
ssh ansible@jellyfin.discus-moth.ts.net "tail -f /opt/jellyfin/tdarr/logs/Tdarr_Node.log"

# Search for errors
ssh ansible@jellyfin.discus-moth.ts.net "grep -i error /opt/jellyfin/tdarr/logs/*.log"
```

### FFmpeg Logs

**Transcode process logs** (detailed encoding info):

```bash
# Usually in Tdarr logs directory
ssh ansible@jellyfin.discus-moth.ts.net "ls -lh /opt/jellyfin/tdarr/logs/ffmpeg"

# View latest transcode log
ssh ansible@jellyfin.discus-moth.ts.net "tail -100 /opt/jellyfin/tdarr/logs/ffmpeg/*.log"
```

## Advanced Troubleshooting

### Complete Container Rebuild

If all else fails, rebuild Tdarr from scratch:

```bash
# SSH to Jellyfin VM
ssh ansible@jellyfin.discus-moth.ts.net

# Stop and remove containers
cd /opt/jellyfin
systemctl --user stop tdarr-server tdarr-node

# Backup current configuration (optional)
sudo tar -czf /tmp/tdarr-backup-$(date +%Y%m%d).tar.gz tdarr/

# Remove all Tdarr data (CAUTION: loses transcode history)
sudo rm -rf tdarr/*

# Re-deploy via Ansible
exit
./bin/runtime/ansible-run.sh playbooks/services/tdarr.yml
```

### Database Corruption

If Web UI shows errors or queue is corrupted:

```bash
# SSH to Jellyfin VM
ssh ansible@jellyfin.discus-moth.ts.net

# Stop containers
systemctl --user stop tdarr-server tdarr-node

# Backup database
sudo cp -r tdarr/server/Tdarr /tmp/tdarr-db-backup

# Remove database (will be recreated)
sudo rm -rf tdarr/server/Tdarr

# Restart containers
systemctl --user start tdarr-server tdarr-node

# Note: Loses transcode history but fixes corruption
```

### Network Debugging

Test node-to-server communication:

```bash
# From node container, test server port
podman exec tdarr-node nc -zv 127.0.0.1 8266"

# Expected: "Connection to 127.0.0.1 8266 port [tcp/*] succeeded!"

# Check server is listening
podman exec tdarr-server ss -tlnp | grep 8266"
```

## Getting Help

### Information to Gather

When asking for help, collect:

1. **Container status**:

   ```bash
   podman ps -a | grep tdarr
   ```

2. **Recent logs**:

   ```bash
   journalctl --user -u tdarr-server --tail 100 > server.log
   journalctl --user -u tdarr-node --tail 100 > node.log
   ```

3. **Resource usage**:

   ```bash
   podman stats --no-stream tdarr-server tdarr-node
   ssh ansible@jellyfin.discus-moth.ts.net "free -h"
   ```

4. **Configuration**:

   ```bash
   cat ~/.config/containers/systemd/tdarr-server.container
   ```

### External Resources

- **Tdarr Discord**: https://discord.gg/GF8jxC8
- **Tdarr GitHub Issues**: https://github.com/HaveAGitGat/Tdarr/issues
- **Tdarr Documentation**: https://docs.tdarr.io/
- **FFmpeg Documentation**: https://ffmpeg.org/documentation.html

### Internal Documentation

- **Setup Guide**: `docs/configuration/tdarr-setup.md`
- **Deployment Plan**: `docs/plans/current-plan.md`
- **Feasibility Analysis**: `docs/troubleshooting/tdarr-feasibility-analysis.md`
- **Playbook**: [`playbooks/services/tdarr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/tdarr.yml)

## Rollback Procedures

### Temporary Disable

```bash
# Stop Tdarr without removing data
systemctl --user stop tdarr-server tdarr-node

# Re-enable when ready
systemctl --user start tdarr-server tdarr-node
```

### Complete Removal

```bash
# Stop and remove containers
ssh ansible@jellyfin.discus-moth.ts.net "systemctl --user stop tdarr-server tdarr-node"

# Remove Tdarr data (CAUTION: irreversible)
ssh ansible@jellyfin.discus-moth.ts.net "sudo rm -rf /opt/jellyfin/tdarr"

# Remove Quadlet files
ssh ansible@jellyfin.discus-moth.ts.net "rm ~/.config/containers/systemd/tdarr*.container"
ssh ansible@jellyfin.discus-moth.ts.net "systemctl --user daemon-reload"

# Remove from Homarr dashboard configuration if added

# Remove firewall rules
ssh ansible@jellyfin.discus-moth.ts.net "sudo ufw delete allow 8265/tcp"
ssh ansible@jellyfin.discus-moth.ts.net "sudo ufw delete allow 8266/tcp"
ssh ansible@jellyfin.discus-moth.ts.net "sudo ufw delete allow 8267/tcp"
```

## Monitoring Best Practices

### Daily Checks

- Check Web UI queue status
- Verify no failed transcodes
- Glance at space savings metric

### Weekly Checks

- Review transcode logs for errors
- Check memory usage trends in Grafana
- Verify temp directory is being cleaned
- Spot-check transcoded file quality

### Monthly Checks

- Review overall space savings
- Optimize transcode profiles based on results
- Update Tdarr to latest version (if stable)
- Clean up old logs
