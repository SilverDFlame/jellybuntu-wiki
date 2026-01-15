# Unpackerr Troubleshooting

Troubleshooting guide for Unpackerr archive extraction issues.

> **IMPORTANT**: Unpackerr runs as a **rootless Podman container with Quadlet** on Download Clients VM (192.168.0.14).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into Download Clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Check Unpackerr service status
systemctl --user status unpackerr

# View Unpackerr logs
journalctl --user -u unpackerr -f

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep unpackerr
```

## Common Issues

### 1. Unpackerr Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start unpackerr.service"
- Container exits immediately

**Diagnosis**:

```bash
# Check service status
systemctl --user status unpackerr

# View detailed logs
journalctl --user -u unpackerr -n 100 --no-pager

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs unpackerr
```

**Solutions**:

1. **Configuration file missing or invalid**:

   ```bash
   # Check config file exists
   ls -la ~/.config/unpackerr/unpackerr.conf

   # View configuration
   cat ~/.config/unpackerr/unpackerr.conf

   # Check for syntax errors in logs
   journalctl --user -u unpackerr | grep -i "error\|invalid\|config"

   # Restore from backup or recreate
   systemctl --user restart unpackerr
   ```

2. **Permission issues**:

   ```bash
   # Check config directory ownership
   ls -la ~/.config/unpackerr/

   # Fix permissions
   chown -R $(whoami):$(whoami) ~/.config/unpackerr/
   ```

3. **Dependencies not running**:

   ```bash
   # Unpackerr depends on download clients being accessible
   systemctl --user status qbittorrent sabnzbd

   # Start dependencies first
   systemctl --user start qbittorrent sabnzbd
   systemctl --user start unpackerr
   ```

4. **Container image issues**:

   ```bash
   # Pull latest image
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull ghcr.io/unpackerr/unpackerr:latest

   # Restart service
   systemctl --user restart unpackerr
   ```

### 2. Archives Not Being Extracted

**Symptoms**:

- Downloaded .rar, .zip files remain compressed
- No extraction happening automatically
- Sonarr/Radarr can't import extracted files

**Diagnosis**:

```bash
# Check Unpackerr logs for extraction attempts
journalctl --user -u unpackerr -f

# Trigger a download and watch logs

# Check if Unpackerr can see download directories
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec unpackerr ls /data/torrents/complete
podman exec unpackerr ls /data/usenet/complete

# Verify archives exist
ls -la /mnt/storage/torrents/complete/*.rar
ls -la /mnt/storage/usenet/complete/*.rar
```

**Solutions**:

1. **Unpackerr not monitoring correct paths**:

   Check configuration file `~/.config/unpackerr/unpackerr.conf`:

   ```ini
   # Should have paths like:
   [sonarr]
   url = http://localhost:8989
   api_key = YOUR_SONARR_API_KEY
   paths = ["/data/torrents/complete", "/data/usenet/complete"]

   [radarr]
   url = http://localhost:7878
   api_key = YOUR_RADARR_API_KEY
   paths = ["/data/torrents/complete", "/data/usenet/complete"]
   ```

   After editing, restart: `systemctl --user restart unpackerr`

2. **qBittorrent/SABnzbd not reporting completion**:

   ```bash
   # Check qBittorrent is accessible
   curl http://localhost:8080

   # Check SABnzbd is accessible
   curl http://localhost:8081

   # Verify Unpackerr can connect
   journalctl --user -u unpackerr | grep -i "qbittorrent\|sabnzbd\|connect"
   ```

3. **API keys incorrect**:
   - Get qBittorrent API key (if enabled)
   - Get SABnzbd API key: SABnzbd → Config → General → Security → API Key
   - Update in `~/.config/unpackerr/unpackerr.conf`
   - Restart: `systemctl --user restart unpackerr`

4. **File permissions prevent extraction**:

   ```bash
   # Check download directory permissions
   ls -la /mnt/storage/torrents/complete/
   ls -la /mnt/storage/usenet/complete/

   # Fix permissions
   ssh nas.discus-moth.ts.net
   sudo chown -R 3000:3000 /mnt/storage/torrents/
   sudo chown -R 3000:3000 /mnt/storage/usenet/
   sudo chmod -R 755 /mnt/storage/torrents/
   sudo chmod -R 755 /mnt/storage/usenet/
   ```

5. **Archives already extracted by download client**:
   - SABnzbd has built-in extraction
   - Check SABnzbd Config → Switches → "Ignore Samples"
   - Disable SABnzbd's extraction if using Unpackerr

### 3. Extraction Fails with Errors

**Symptoms**:

- "Extraction failed" in logs
- Partial extraction
- CRC errors or password-protected archives

**Diagnosis**:

```bash
# Check logs for specific error messages
journalctl --user -u unpackerr | grep -i "error\|fail\|crc\|password"

# Check if unrar/7zip tools available in container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec unpackerr which unrar
podman exec unpackerr which 7z
```

**Solutions**:

1. **Password-protected archives**:

   ```bash
   # Check logs for password errors
   journalctl --user -u unpackerr | grep -i "password"

   # Configure archive password in unpackerr.conf
   nano ~/.config/unpackerr/unpackerr.conf

   # Add under [general]:
   # passwords = ["password1", "password2"]

   # Restart
   systemctl --user restart unpackerr
   ```

2. **Corrupted archive files**:

   ```bash
   # Test archive manually
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec unpackerr unrar t /data/torrents/complete/file.rar

   # If corrupted, re-download the file
   ```

3. **Insufficient disk space**:

   ```bash
   # Check available space
   df -h /mnt/storage

   # Extraction needs space for both archive and extracted files
   # Clean up old downloads or increase storage
   ```

4. **Multi-part archives incomplete**:

   ```bash
   # Check all .rar parts are present
   ls -la /mnt/storage/torrents/complete/*.rar
   ls -la /mnt/storage/torrents/complete/*.r[0-9][0-9]

   # Unpackerr waits for all parts before extracting
   # Verify download completed fully
   ```

5. **Archive format not supported**:

   ```bash
   # Unpackerr supports: .rar, .zip, .7z, .tar, .tar.gz, .tar.bz2
   # Check file extension
   ls -la /mnt/storage/torrents/complete/

   # Unsupported formats must be extracted manually
   ```

### 4. Extracted Files Not Imported by Sonarr/Radarr

**Symptoms**:

- Extraction succeeds
- Files remain in download directory
- Sonarr/Radarr don't import extracted media

**Diagnosis**:

```bash
# Check if files were extracted
ls -la /mnt/storage/torrents/complete/

# Check Sonarr/Radarr logs for import attempts
ssh media-services.discus-moth.ts.net
journalctl --user -u sonarr | tail -50
journalctl --user -u radarr | tail -50

# Verify Unpackerr triggered import
journalctl --user -u unpackerr | grep -i "import\|complete"
```

**Solutions**:

1. **Sonarr/Radarr not configured to import extracted files**:
   - Sonarr/Radarr → Settings → Download Clients
   - Verify "Remove" or "Import" is enabled
   - Check category mapping matches (tv/movies)

2. **Files extracted to wrong location**:

   ```bash
   # Unpackerr should extract in-place
   # Check extraction path in logs
   journalctl --user -u unpackerr | grep -i "extract"

   # Files should be in same directory as archive
   ```

3. **Sonarr/Radarr can't access extracted files**:

   ```bash
   # Verify path mapping in Sonarr/Radarr
   # Settings → Download Clients → Remote Path Mappings

   # Should map:
   # Host: download-clients.discus-moth.ts.net
   # Remote Path: /data/torrents/complete
   # Local Path: /data/media/tv (or movies)
   ```

4. **Manual import needed**:
   - Sonarr → Activity → Queue → Manual Import
   - Select files and import manually

### 5. High CPU/Disk Usage During Extraction

**Symptoms**:

- System slowdown during extraction
- High I/O wait times
- Extraction takes very long

**Diagnosis**:

```bash
# Check resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats unpackerr --no-stream

# Check I/O usage
iostat -x 1 5

# Check what's being extracted
journalctl --user -u unpackerr -f
```

**Solutions**:

1. **Large archive files**:
   - Extraction of multi-GB archives is CPU/disk intensive
   - This is normal behavior
   - Consider scheduling downloads during low-usage hours

2. **Multiple simultaneous extractions**:

   Configure in `~/.config/unpackerr/unpackerr.conf`:

   ```ini
   [general]
   parallel = 1   # Extract one archive at a time
   # Change to 2-3 if you have resources
   ```

   Restart: `systemctl --user restart unpackerr`

3. **Slow NFS performance**:

   ```bash
   # Check NFS mount options
   mount | grep /mnt/storage

   # Should have: rsize=1048576,wsize=1048576
   # See docs/troubleshooting/nas-nfs.md for optimization
   ```

4. **Container resource limits**:

   ```bash
   # Check if container is resource-limited
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman inspect unpackerr | grep -A 5 "Memory\|Cpu"

   # Increase limits if necessary (edit Quadlet .container file)
   ```

### 6. Unpackerr Not Detecting Completed Downloads

**Symptoms**:

- Downloads complete but Unpackerr doesn't see them
- No extraction attempts logged
- Manual extraction works

**Diagnosis**:

```bash
# Check if Unpackerr is polling download clients
journalctl --user -u unpackerr | grep -i "poll\|check\|scan"

# Verify download client connections
journalctl --user -u unpackerr | grep -i "qbittorrent\|sabnzbd"

# Check download completion in clients
curl http://localhost:8080   # qBittorrent Web UI
curl http://localhost:8081   # SABnzbd Web UI
```

**Solutions**:

1. **Polling interval too long**:

   Edit `~/.config/unpackerr/unpackerr.conf`:

   ```ini
   [general]
   interval = 2m   # Check every 2 minutes (default)
   # Reduce to 1m for faster detection
   ```

   Restart: `systemctl --user restart unpackerr`

2. **Download client webhooks not configured**:
   - qBittorrent: Options → Web UI → "Run external program on torrent completion"
   - SABnzbd: Config → Categories → Post-Processing Script
   - This allows instant notification instead of polling

3. **Download not fully complete**:
   - Torrent may still be seeding
   - Check torrent status in qBittorrent
   - Archives only extracted when torrent marked complete

4. **Connection to download clients failed**:

   ```bash
   # Test connectivity
   curl http://localhost:8080   # qBittorrent
   curl http://localhost:8081   # SABnzbd

   # Check credentials in unpackerr.conf
   # Restart Unpackerr
   systemctl --user restart unpackerr
   ```

### 7. Old Archives Not Cleaned Up

**Symptoms**:

- Extracted files left behind
- Original .rar archives not deleted
- Disk space filling up

**Diagnosis**:

```bash
# Check for leftover archives
find /mnt/storage/torrents/complete/ -name "*.rar" -mtime +7
find /mnt/storage/usenet/complete/ -name "*.rar" -mtime +7

# Check Unpackerr cleanup settings
cat ~/.config/unpackerr/unpackerr.conf | grep -i "delete\|cleanup"
```

**Solutions**:

1. **Configure automatic cleanup**:

   Edit `~/.config/unpackerr/unpackerr.conf`:

   ```ini
   [general]
   delete_after = 10m   # Delete archives 10 minutes after extraction
   delete_files = true  # Enable deletion of archives
   ```

   Restart: `systemctl --user restart unpackerr`

2. **Manual cleanup**:

   ```bash
   # Remove old .rar archives (older than 7 days)
   find /mnt/storage/torrents/complete/ -name "*.rar" -mtime +7 -delete
   find /mnt/storage/usenet/complete/ -name "*.r[0-9][0-9]" -mtime +7 -delete
   ```

3. **Let download clients handle cleanup**:
   - qBittorrent: Options → BitTorrent → "Remove torrents when seeding time reached"
   - SABnzbd: Config → Switches → "Cleanup List" → delete after X days

## Advanced Troubleshooting

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat unpackerr

# View Quadlet .container file
cat ~/.config/containers/systemd/unpackerr.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart unpackerr
```

### Manual Extraction Test

```bash
# Enter container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it unpackerr /bin/sh

# Test extraction manually
cd /data/torrents/complete/
unrar x test-file.rar

# Check extracted files
ls -la

# Exit
exit
```

### Verify Volume Mounts

```bash
# Check volume mounts
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman inspect unpackerr | grep -A 20 Mounts

# Should show:
# /mnt/storage -> /data
```

### Configuration File Reference

Example `~/.config/unpackerr/unpackerr.conf`:

```ini
[general]
debug = false
interval = 2m
parallel = 1
delete_files = true
delete_after = 10m

[sonarr]
url = http://localhost:8989
api_key = YOUR_SONARR_API_KEY
paths = ["/data/torrents/complete", "/data/usenet/complete"]
protocols = "torrent,usenet"

[radarr]
url = http://localhost:7878
api_key = YOUR_RADARR_API_KEY
paths = ["/data/torrents/complete", "/data/usenet/complete"]
protocols = "torrent,usenet"
```

### Backup and Restore

```bash
# Backup Unpackerr configuration
systemctl --user stop unpackerr
tar -czf ~/unpackerr-backup-$(date +%Y%m%d).tar.gz ~/.config/unpackerr/
systemctl --user start unpackerr

# Restore from backup
systemctl --user stop unpackerr
rm -rf ~/.config/unpackerr/
tar -xzf ~/unpackerr-backup-*.tar.gz -C ~/
systemctl --user start unpackerr
```

## Getting Help

If issues persist after trying these solutions:

1. **Collect logs**:

   ```bash
   journalctl --user -u unpackerr -n 500 --no-pager > /tmp/unpackerr.log
   ```

2. **Enable debug logging**:

   Edit `~/.config/unpackerr/unpackerr.conf`:

   ```ini
   [general]
   debug = true
   ```

   Restart: `systemctl --user restart unpackerr`

   View logs: `journalctl --user -u unpackerr -f`

3. **Gather diagnostic info**:

   ```bash
   # Unpackerr version
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec unpackerr unpackerr --version

   # Container status
   podman ps -a | grep unpackerr
   podman inspect unpackerr

   # Configuration
   cat ~/.config/unpackerr/unpackerr.conf
   ```

4. **Unpackerr community resources**:
   - GitHub: https://github.com/Unpackerr/unpackerr/issues
   - Discord: Check GitHub for invite link
   - Documentation: https://unpackerr.zip/

## See Also

- [Unpackerr Configuration Guide](../configuration/unpackerr-setup.md) - Initial setup instructions
- [Download Clients Troubleshooting](download-clients.md) - qBittorrent and SABnzbd issues
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md) - Import issues
- [NAS/NFS Troubleshooting](nas-nfs.md) - Storage performance
- [Service Endpoints](../configuration/service-endpoints.md) - Download Clients VM information
