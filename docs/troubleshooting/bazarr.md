# Bazarr Troubleshooting

Troubleshooting guide for Bazarr subtitle management issues.

> **IMPORTANT**: Bazarr runs as a **rootless Podman container with Quadlet** on Media Services VM (192.168.30.13).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into Media Services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check Bazarr service status
systemctl --user status bazarr

# View Bazarr logs
journalctl --user -u bazarr -f

# Check web UI access
curl http://localhost:6767

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep bazarr
```

## Common Issues

### 1. Bazarr Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start bazarr.service"
- Container exits immediately

**Diagnosis**:

```bash
# Check service status
systemctl --user status bazarr

# View detailed logs
journalctl --user -u bazarr -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :6767

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs bazarr
```

**Solutions**:

1. **Port 6767 already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :6767
   # Stop the conflicting service
   ```

2. **Permission issues**:

   ```bash
   # Check config directory ownership
   ls -la ~/.config/bazarr/

   # Fix permissions (should be owned by your user)
   chown -R $(whoami):$(whoami) ~/.config/bazarr/
   ```

3. **Database corruption**:

   ```bash
   # Stop Bazarr
   systemctl --user stop bazarr

   # Backup and remove database
   cp ~/.config/bazarr/db/bazarr.db ~/.config/bazarr/db/bazarr.db.bak
   rm ~/.config/bazarr/db/bazarr.db

   # Restart (will create new database)
   systemctl --user start bazarr
   # Reconfigure Sonarr/Radarr connections in Web UI
   ```

4. **Container image issues**:

   ```bash
   # Pull latest image
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull lscr.io/linuxserver/bazarr:latest

   # Restart service
   systemctl --user restart bazarr
   ```

### 2. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://media-services.discus-moth.ts.net:6767
- Can't reach http://192.168.30.13:6767

**Diagnosis**:

```bash
# Check if Bazarr is running
systemctl --user status bazarr

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:6767

# Check port is listening
sudo netstat -tulpn | grep 6767
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # Allow Bazarr port
   sudo ufw allow from 192.168.30.0/24 to any port 6767
   sudo ufw allow from 100.64.0.0/10 to any port 6767
   sudo ufw reload
   ```

2. **Service not running**:

   ```bash
   systemctl --user start bazarr
   systemctl --user enable bazarr
   ```

3. **Container networking issues**:

   ```bash
   # Check container ports
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman port bazarr

   # Should show: 6767/tcp -> 0.0.0.0:6767
   ```

### 3. Can't Connect to Sonarr/Radarr

**Symptoms**:

- Error: "Unable to connect to Sonarr/Radarr"
- Connection test fails
- "Connection refused" or timeout errors

**Diagnosis**:

```bash
# Test connectivity to Sonarr/Radarr
curl http://localhost:8989   # Sonarr
curl http://localhost:7878   # Radarr

# Check from inside container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec bazarr curl http://localhost:8989
podman exec bazarr curl http://localhost:7878
```

**Solutions**:

1. **Wrong hostname configuration**:
   - Use `localhost` or `sonarr`/`radarr` (container names)
   - NOT Tailscale hostname (media-services.discus-moth.ts.net)
   - NOT `127.0.0.1` (use `localhost` instead)

2. **Incorrect API keys**:
   - Get Sonarr API: Sonarr → Settings → General → Security → API Key
   - Get Radarr API: Radarr → Settings → General → Security → API Key
   - Update in Bazarr → Settings → Sonarr/Radarr

3. **Sonarr/Radarr not running**:

   ```bash
   systemctl --user status sonarr
   systemctl --user status radarr
   systemctl --user start sonarr radarr
   ```

4. **Base URL mismatch**:
   - In Bazarr settings, Base URL should be empty (just `/`)
   - Unless Sonarr/Radarr have custom base URL configured

### 4. Subtitles Not Downloading

**Symptoms**:

- Subtitles marked as "wanted" but never download
- Provider errors in logs
- "No subtitles found" for available content

**Diagnosis**:

```bash
# Check Bazarr logs for provider errors
journalctl --user -u bazarr | grep -i "provider\|error\|subtitle"

# Check provider status in Web UI
# Settings → Providers → check status icons

# View recent subtitle searches
# History tab in Web UI
```

**Solutions**:

1. **No providers configured**:
   - Settings → Providers
   - Add at least one provider (OpenSubtitles, Addic7ed, Podnapisi)
   - Configure API keys/credentials if required
   - See [Bazarr Configuration Guide](../configuration/bazarr-setup.md#4-configure-subtitle-providers)

2. **Provider rate limiting**:
   - Providers have API rate limits (especially free accounts)
   - Check System → Providers for rate limit status
   - Wait for rate limit to reset
   - Add additional providers to distribute load

3. **Minimum score too high**:
   - Settings → Sonarr/Radarr
   - Reduce "Minimum Score" from 85 to 70
   - This allows lower-quality matches

4. **Language not configured**:
   - Settings → Languages
   - Verify desired language is added (e.g., English)
   - Create language profile
   - Assign profile to Sonarr/Radarr

5. **Provider authentication failed**:

   ```bash
   # Check logs for auth errors
   journalctl --user -u bazarr | grep -i "auth\|credential\|api key"

   # Verify credentials in Settings → Providers
   # Re-enter username/password or API key
   # Click Test to verify
   ```

6. **Media files not accessible**:

   ```bash
   # Check NFS mount
   df -h /mnt/storage
   mount | grep /mnt/storage

   # Verify Bazarr can read media files
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec bazarr ls /data/media/tv
   podman exec bazarr ls /data/media/movies
   ```

### 5. Library Not Syncing from Sonarr/Radarr

**Symptoms**:

- Series/Movies not appearing in Bazarr
- Library shows empty
- "No data" in Series/Movies tabs

**Diagnosis**:

```bash
# Check sync task logs
journalctl --user -u bazarr | grep -i "sync\|sonarr\|radarr"

# Verify Sonarr/Radarr connections
# Settings → Sonarr/Radarr → Test connection
```

**Solutions**:

1. **Manual full sync**:
   - Settings → Sonarr → Click "Full Sync"
   - Settings → Radarr → Click "Full Sync"
   - Wait for sync to complete (System → Tasks)

2. **Sync task not running**:
   - Settings → Scheduler
   - Verify "Update Library" task is enabled
   - Default: Every 6 hours
   - Manually trigger: System → Tasks → Update Series/Movies

3. **Connection issues**:
   - Verify Sonarr/Radarr API keys are correct
   - Check Sonarr/Radarr are accessible (see Issue #3)
   - Test connection: Settings → Sonarr/Radarr → Test

4. **Download Only Monitored enabled**:
   - Settings → Sonarr/Radarr
   - "Download Only Monitored" setting filters content
   - Only monitored series/movies appear in Bazarr
   - Verify content is monitored in Sonarr/Radarr

### 6. Subtitles Downloaded But Not Showing in Jellyfin

**Symptoms**:

- Bazarr shows subtitle downloaded
- Subtitle files exist on disk
- Jellyfin doesn't show subtitles during playback

**Diagnosis**:

```bash
# Check subtitle files exist
ls -la /mnt/storage/media/tv/*/  | grep .srt
ls -la /mnt/storage/media/movies/*/  | grep .srt

# Verify file permissions
ls -l /mnt/storage/media/tv/*/*.srt

# Check Jellyfin can read files
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net
sudo -u jellyfin ls /mnt/data/media/tv/*/*.srt
```

**Solutions**:

1. **Subtitle file permissions**:

   ```bash
   # Fix permissions (run on NAS VM)
   sudo chown -R 3000:3000 /mnt/storage/media/
   sudo chmod -R 755 /mnt/storage/media/
   ```

2. **Jellyfin needs library refresh**:
   - Jellyfin → Dashboard → Libraries
   - Select library → Scan Library
   - Wait for scan to complete

3. **Subtitle filename doesn't match media**:
   - Subtitle must have same name as video file
   - Example: `Movie.mkv` → `Movie.en.srt`
   - Check Settings → Subtitles → "Use Scene Name"

4. **Subtitle encoding issues**:
   - Settings → Subtitles
   - Enable "UTF-8 Encoding"
   - Re-download subtitles

### 7. Wrong Language Subtitles Downloaded

**Symptoms**:

- Subtitles in unexpected language
- Multiple language files downloaded
- Language filter not working

**Diagnosis**:

```bash
# Check language configuration
# Settings → Languages → Verify enabled languages

# Check language profile
# Settings → Languages → Profiles
```

**Solutions**:

1. **Multiple languages enabled**:
   - Settings → Languages
   - Remove unwanted languages
   - Keep only desired language (e.g., English)

2. **Language profile not applied**:
   - Settings → Languages → Profiles
   - Create profile with single language
   - Settings → Sonarr/Radarr
   - Assign language profile

3. **Single Language setting disabled**:
   - Settings → Languages
   - Enable "Single Language"
   - This prevents multiple subtitle files per language

4. **Clear subtitle cache**:
   - System → Tasks
   - Run "Clear All Subtitles Cache"
   - Trigger new searches

### 8. High CPU/Memory Usage

**Symptoms**:

- Bazarr using excessive resources
- System slowdown during subtitle searches
- Container frequently restarting

**Diagnosis**:

```bash
# Check resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats bazarr --no-stream

# Check for stuck tasks
journalctl --user -u bazarr | grep -i "task\|search"
```

**Solutions**:

1. **Too many concurrent searches**:
   - Settings → General
   - Reduce "Maximum number of concurrent downloads" to 2-3

2. **Search interval too aggressive**:
   - Settings → Scheduler
   - Increase "Search for Missing Subtitles" interval from 3 hours to 6 hours
   - Reduce "Upgrade Previously Downloaded Subtitles" frequency

3. **Large library causing heavy scans**:
   - Settings → Scheduler
   - Increase "Update Library" interval to 12 or 24 hours

4. **Provider timeout issues**:

   ```bash
   # Restart Bazarr to clear stuck requests
   systemctl --user restart bazarr
   ```

## Advanced Troubleshooting

### Database Corruption Recovery

```bash
# Stop Bazarr
systemctl --user stop bazarr

# Backup database
cp -r ~/.config/bazarr/db/ ~/.config/bazarr/db.backup/

# Try repair (if sqlite3 available)
sqlite3 ~/.config/bazarr/db/bazarr.db "PRAGMA integrity_check;"

# If corrupted, start fresh (loses settings!)
rm ~/.config/bazarr/db/bazarr.db

# Restart
systemctl --user start bazarr
```

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat bazarr

# View Quadlet .container file
cat ~/.config/containers/systemd/bazarr.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart bazarr
```

### Provider Debugging

```bash
# Check provider connectivity
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec bazarr wget -O- https://www.opensubtitles.com

# View provider rate limits in logs
journalctl --user -u bazarr | grep -i "rate limit"

# Test specific provider
# Web UI → System → Providers → click Test
```

### Container Volume Debugging

```bash
# Verify volume mounts
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman inspect bazarr | grep -A 20 Mounts

# Should show:
# /mnt/storage/media -> /data/media
# ~/.config/bazarr -> /config
```

### Backup and Restore

```bash
# Backup Bazarr configuration
systemctl --user stop bazarr
tar -czf ~/bazarr-backup-$(date +%Y%m%d).tar.gz ~/.config/bazarr/
systemctl --user start bazarr

# Restore from backup
systemctl --user stop bazarr
rm -rf ~/.config/bazarr/
tar -xzf ~/bazarr-backup-*.tar.gz -C ~/
systemctl --user start bazarr
```

## Getting Help

If issues persist after trying these solutions:

1. **Collect logs**:

   ```bash
   journalctl --user -u bazarr -n 500 --no-pager > /tmp/bazarr.log
   ```

2. **Enable debug logging**:
   - Settings → General → Log Level
   - Change to "Debug"
   - Restart: `systemctl --user restart bazarr`
   - Check logs: `journalctl --user -u bazarr -f`

3. **Gather diagnostic info**:

   ```bash
   # Bazarr version
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec bazarr cat /app/bazarr/bazarr/version.txt

   # Container status
   podman ps -a | grep bazarr
   podman inspect bazarr
   ```

4. **Bazarr community resources**:
   - Official docs: https://wiki.bazarr.media/
   - GitHub: https://github.com/morpheus65535/bazarr/issues
   - Discord: https://discord.gg/MH2e2eb
   - Reddit: r/bazarr

## See Also

- [Bazarr Configuration Guide](../configuration/bazarr-setup.md) - Initial setup instructions
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md) - Connection issues
- [NAS/NFS Troubleshooting](nas-nfs.md) - File access issues
- [Jellyfin Troubleshooting](jellyfin.md) - Subtitle playback issues
- [Service Endpoints](../configuration/service-endpoints.md) - Bazarr access information
