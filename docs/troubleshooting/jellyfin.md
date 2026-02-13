# Jellyfin Troubleshooting

Troubleshooting guide for Jellyfin media server issues.

> **IMPORTANT**: Jellyfin runs as a **native system service** (not Docker). Use `systemctl` and `journalctl` commands,
NOT `docker` commands.

## Quick Checks

```bash
# Check Jellyfin service status
sudo systemctl status jellyfin

# View Jellyfin logs
sudo journalctl -u jellyfin -f

# Check if Jellyfin is listening
sudo netstat -tulpn | grep 8096

# Verify NFS mount
df -h /mnt/data
```

## Common Issues

### 1. Jellyfin Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start Jellyfin Media Server"

**Diagnosis**:

```bash
# Check service status
sudo systemctl status jellyfin

# View detailed logs
sudo journalctl -u jellyfin -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :8096
```

**Solutions**:

1. **Port already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :8096
   # Kill or stop the conflicting service
   ```

2. **Permission issues**:

   ```bash
   # Fix Jellyfin config directory permissions
   sudo chown -R jellyfin:jellyfin /etc/jellyfin
   sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
   sudo chown -R jellyfin:jellyfin /var/cache/jellyfin
   sudo chown -R jellyfin:jellyfin /var/log/jellyfin
   ```

3. **Corrupted database**:

   ```bash
   # Backup and reset database
   sudo systemctl stop jellyfin
   sudo mv /var/lib/jellyfin/data/library.db /var/lib/jellyfin/data/library.db.bak
   sudo systemctl start jellyfin
   # Reconfigure in web UI
   ```

### 2. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://jellyfin.discus-moth.ts.net:8096

**Diagnosis**:

```bash
# Check if Jellyfin is running
sudo systemctl status jellyfin

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:8096

# Check if accessible from Tailscale IP
curl http://$(tailscale ip -4):8096
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # Allow Jellyfin port
   sudo ufw allow from 192.168.30.0/24 to any port 8096
   sudo ufw allow from 100.64.0.0/10 to any port 8096
   sudo ufw reload
   ```

2. **Tailscale not connected**:

   ```bash
   # Check Tailscale status
   tailscale status

   # Restart if needed
   sudo systemctl restart tailscaled
   ```

3. **Service not running**:

   ```bash
   sudo systemctl start jellyfin
   sudo systemctl enable jellyfin
   ```

### 3. Transcoding Issues

**Symptoms**:

- Video playback stutters or buffers constantly
- Transcoding fails with errors
- High CPU usage during playback

**Diagnosis**:

```bash
# Check CPU usage
top -u jellyfin

# View transcoding logs
tail -f /var/log/jellyfin/ffmpeg-*.txt

# Check available CPU
lscpu
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Solutions**:

1. **CPU governor not set to performance**:

   ```bash
   # Set to performance mode (should be done by playbook)
   for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
     echo performance | sudo tee $cpu
   done
   ```

2. **Insufficient resources**:
   - Check VM has 4 cores allocated (see docs/architecture.md)
   - Verify high CPU priority is set (cpu_units: 2048)
   - Consider reducing concurrent transcodes in Settings > Playback

3. **Codec issues**:

   ```bash
   # Verify ffmpeg codecs
   /usr/lib/jellyfin-ffmpeg/ffmpeg -codecs | grep h264
   /usr/lib/jellyfin-ffmpeg/ffmpeg -codecs | grep hevc
   ```

4. **Enable hardware acceleration** (if available):
   - Dashboard > Playback > Hardware Acceleration
   - Note: Current setup uses software transcoding only

### 4. Media Library Not Showing Files

**Symptoms**:

- Library appears empty
- New media not detected automatically
- "No items found" in library

**Diagnosis**:

```bash
# Check NFS mount
df -h /mnt/data
ls -la /mnt/data/media/tv
ls -la /mnt/data/media/movies

# Check file permissions
ls -l /mnt/data/media/

# Verify jellyfin user can read files
sudo -u jellyfin ls /mnt/data/media/tv
```

**Solutions**:

1. **NFS not mounted**:

   ```bash
   # Check mounts
   mount | grep /mnt/data

   # Remount if needed
   sudo mount -a

   # Check /etc/fstab entry
   grep /mnt/data /etc/fstab
   ```

2. **Permission issues**:

   ```bash
   # Verify jellyfin is in nfsusers group
   groups jellyfin

   # Add if missing
   sudo usermod -aG nfsusers jellyfin
   sudo systemctl restart jellyfin
   ```

3. **Wrong library path**:
   - Verify library paths in Dashboard > Libraries
   - Should be `/mnt/data/media/tv` and `/mnt/data/media/movies`
   - Not `/data/media/` or other paths

4. **Trigger manual scan**:
   - Dashboard > Libraries > [Library Name] > Scan Library

### 5. Performance Issues / Slow UI

**Symptoms**:

- Web UI is slow to respond
- Library browsing is sluggish
- Database queries timeout

**Diagnosis**:

```bash
# Check system resources
free -h
df -h
iostat -x 1

# Check Jellyfin process priority
ps aux | grep jellyfin | grep -v grep

# View active connections
sudo netstat -an | grep :8096 | wc -l
```

**Solutions**:

1. **Database optimization**:

   ```bash
   # Stop Jellyfin
   sudo systemctl stop jellyfin

   # Optimize database
   sudo sqlite3 /var/lib/jellyfin/data/library.db "VACUUM;"
   sudo sqlite3 /var/lib/jellyfin/data/library.db "REINDEX;"

   # Start Jellyfin
   sudo systemctl start jellyfin
   ```

2. **Clear cache**:

   ```bash
   sudo systemctl stop jellyfin
   sudo rm -rf /var/cache/jellyfin/*
   sudo systemctl start jellyfin
   ```

3. **Check system limits** (should be set by playbook):

   ```bash
   # Verify limits
   sudo -u jellyfin ulimit -n    # Should be high (10000+)
   sudo -u jellyfin ulimit -l    # memlock
   ```

4. **Reduce metadata downloads**:
   - Dashboard > Libraries > [Library] > Manage Library
   - Disable unnecessary metadata providers

### 6. Subtitles Not Working

**Symptoms**:

- Subtitles don't appear during playback
- Error downloading subtitles

**Diagnosis**:

```bash
# Check subtitle plugins
ls /var/lib/jellyfin/plugins/

# View logs
sudo journalctl -u jellyfin | grep -i subtitle
```

**Solutions**:

1. **Install subtitle plugin**:
   - Dashboard > Plugins > Catalog
   - Install "Open Subtitles" or preferred provider

2. **Check subtitle formats**:
   - Supported: SRT, ASS, SSA, VTT, SUB
   - Place subtitles next to media files with same name

3. **Enable subtitle extraction**:
   - Dashboard > Playback > Enable subtitle extraction

### 7. Remote Access Not Working

**Symptoms**:

- Can't access Jellyfin from outside local network
- Tailscale access works but want internet access

**Diagnosis**:

```bash
# Check public IP
curl ifconfig.me

# Check firewall
sudo ufw status

# Verify Jellyfin accessible locally
curl http://localhost:8096
```

**Solutions**:

1. **Use Tailscale** (recommended):
   - Access via `http://jellyfin.discus-moth.ts.net:8096`
   - No port forwarding needed
   - Secure and private

2. **Port forwarding** (not recommended without HTTPS):
   - Forward router port 8096 to 192.168.30.12:8096
   - Set up HTTPS first (Let's Encrypt)
   - Use reverse proxy (Nginx/Caddy)

## Advanced Troubleshooting

### Check System Configuration

```bash
# Verify CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check Nice value (should be -10)
ps -o nice,comm,pid -C jellyfin

# Verify memory limits
sudo systemctl show jellyfin | grep -i limit

# Check IO priority
sudo iotop -o -b -n 1 | grep jellyfin
```

### Analyze Transcoding Performance

```bash
# Monitor transcoding in real-time
watch -n 1 'ps aux | grep ffmpeg | grep -v grep'

# Check transcode directory
ls -lh /var/lib/jellyfin/transcodes/

# Clean old transcodes
sudo systemctl stop jellyfin
sudo rm -rf /var/lib/jellyfin/transcodes/*
sudo systemctl start jellyfin
```

### Reset Jellyfin (Last Resort)

```bash
# Backup configuration
sudo systemctl stop jellyfin
sudo tar -czf /tmp/jellyfin-backup-$(date +%Y%m%d).tar.gz \
  /etc/jellyfin \
  /var/lib/jellyfin \
  /var/cache/jellyfin

# Purge and reinstall
sudo apt purge jellyfin
sudo rm -rf /etc/jellyfin /var/lib/jellyfin /var/cache/jellyfin
sudo apt install jellyfin

# Restore if needed
sudo systemctl stop jellyfin
sudo tar -xzf /tmp/jellyfin-backup-*.tar.gz -C /
sudo systemctl start jellyfin
```

## Getting Help

If issues persist after trying these solutions:

1. **Check Jellyfin logs**:

   ```bash
   sudo journalctl -u jellyfin -n 500 --no-pager > /tmp/jellyfin.log
   ```

2. **Check system logs**:

   ```bash
   dmesg | tail -100
   ```

3. **Gather diagnostic info**:

   ```bash
   # System info
   uname -a
   lsb_release -a

   # Jellyfin version
   jellyfin --version

   # Resource usage
   free -h
   df -h
   ```

4. **Jellyfin community resources**:
   - Official docs: https://jellyfin.org/docs/
   - Forum: https://forum.jellyfin.org/
   - GitHub: https://github.com/jellyfin/jellyfin/issues

## See Also

- [VM Specifications](../reference/vm-specifications.md) - Jellyfin VM resources
- [NAS/NFS Troubleshooting](nas-nfs.md) - NFS mount issues
- [Networking Troubleshooting](networking.md) - Tailscale and firewall issues
- [Common Issues](common-issues.md) - Cross-service problems
