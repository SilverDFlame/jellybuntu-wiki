# Sonarr/Radarr Troubleshooting

Troubleshooting guide for Sonarr (TV) and Radarr (Movies) media management issues.

> **IMPORTANT**: Sonarr and Radarr run as **rootless Podman containers with Quadlet** on the media-services VM
> (192.168.0.13). Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check service status
systemctl --user status sonarr radarr

# View logs
journalctl --user -u sonarr -f
journalctl --user -u radarr -f

# Check containers are running
podman ps | grep -E "sonarr|radarr"

# View container logs
podman logs sonarr --tail 100
podman logs radarr --tail 100

# Check web UI access
curl http://localhost:8989  # Sonarr
curl http://localhost:7878  # Radarr

# Verify NFS mount
df -h /mnt/data
```

## Common Issues

### 1. Service Not Accessible

**Symptoms**:

- Can't access http://media-services.discus-moth.ts.net:8989 (Sonarr)
- Can't access http://media-services.discus-moth.ts.net:7878 (Radarr)
- Connection timeout or refused

**Diagnosis**:

```bash
# Check service status
systemctl --user status sonarr radarr

# Check container status
podman ps -a | grep -E "sonarr|radarr"

# Check container logs
podman logs sonarr --tail 50
podman logs radarr --tail 50

# Check if port is listening
ss -tlnp | grep -E "8989|7878"

# Test local access
curl http://localhost:8989
curl http://localhost:7878
```

**Solutions**:

1. **Service not running**:

   ```bash
   systemctl --user start sonarr radarr
   systemctl --user enable sonarr radarr
   ```

2. **Port conflict**:

   ```bash
   # Check what's using the port
   sudo lsof -i :8989
   sudo lsof -i :7878
   ```

3. **Firewall blocking**:

   ```bash
   sudo ufw allow from 192.168.0.0/24 to any port 8989
   sudo ufw allow from 192.168.0.0/24 to any port 7878
   sudo ufw allow from 100.64.0.0/10 to any port 8989
   sudo ufw allow from 100.64.0.0/10 to any port 7878
   sudo ufw reload
   ```

4. **Quadlet configuration issue**:

   ```bash
   # Check Quadlet files exist
   ls -la ~/.config/containers/systemd/sonarr.container
   ls -la ~/.config/containers/systemd/radarr.container

   # Reload systemd and restart
   systemctl --user daemon-reload
   systemctl --user restart sonarr radarr
   ```

### 2. Can't Connect to Download Clients

**Symptoms**:

- Error: "Unable to connect to qBittorrent"
- Error: "Unable to connect to SABnzbd"
- Downloads don't start

**Diagnosis**:

```bash
# Test connectivity to download clients VM
curl http://download-clients.discus-moth.ts.net:8080  # qBittorrent
curl http://download-clients.discus-moth.ts.net:8081  # SABnzbd

# Check from inside container
podman exec sonarr ping -c 3 download-clients.discus-moth.ts.net

# Test with wget
podman exec sonarr wget -O- http://192.168.0.14:8080
```

**Solutions**:

1. **Wrong hostname/IP**:
   - Use `download-clients.discus-moth.ts.net` (Tailscale)
   - Or use `192.168.0.14` (local IP)
   - NOT `localhost` or `127.0.0.1`

2. **Wrong port**:
   - qBittorrent: Port 8080
   - SABnzbd: Port 8081

3. **Authentication issues**:
   - qBittorrent: Check username/password in download client settings
   - SABnzbd: Verify API key is correct

4. **Test from container**:

   ```bash
   podman exec sonarr wget -O- http://192.168.0.14:8080
   podman exec radarr wget -O- http://192.168.0.14:8080
   ```

### 3. Prowlarr Indexers Not Syncing

**Symptoms**:

- Indexers don't appear in Sonarr/Radarr
- Error: "Unable to connect to Prowlarr"
- Sync shows failed

**Diagnosis**:

```bash
# Check Prowlarr is running
systemctl --user status prowlarr
podman ps | grep prowlarr

# View Prowlarr logs
journalctl --user -u prowlarr -f

# Test Prowlarr connectivity
curl http://localhost:9696/api/v1/health
```

**Solutions**:

1. **Incorrect Prowlarr settings in Sonarr/Radarr**:
   - Settings > Apps > Add Application
   - **Prowlarr Server**: `http://localhost:9696` or `http://192.168.0.13:9696`
   - **Sonarr/Radarr Server**: `http://localhost:8989` or `http://localhost:7878`
   - Verify API keys are correct

2. **Test connectivity between services**:

   ```bash
   # All services run on same VM, so localhost works
   curl http://localhost:9696
   curl http://localhost:8989
   curl http://localhost:7878
   ```

3. **Force sync**:
   - Prowlarr > Settings > Apps > [App] > Test & Save
   - Or click Sync button

### 4. Missing Episodes Not Being Found Automatically

**Symptoms**:

- Episodes marked as "Wanted" in Sonarr
- Automatic searches don't find releases
- Manual Interactive Search finds releases immediately
- Backlog episodes from older series never download

**Understanding the Issue**:

- **RSS Sync** in Sonarr only catches NEW releases (last 24-48 hours from indexers' RSS feeds)
- Backlog episodes from older series (2020 and earlier) are NOT in current RSS feeds
- Manual searches work because they actively query indexers for specific content
- You need a backlog search solution for old/wanted episodes

**Diagnosis**:

```bash
# Check RSS sync is working
# Sonarr → System → Tasks → RSS Sync (should run every 15 minutes)

# Check indexers are enabled
# Sonarr → Settings → Indexers (all should have green checkmarks)

# Verify Prowlarr sync
# Prowlarr → Settings → Apps → Sonarr (Test connection)
```

#### Solutions

##### Option 1: Use Huntarr (Recommended - Automatic Backlog Searches)

Huntarr is specifically designed to solve this problem by automatically searching for missing/wanted content on a
schedule.

1. **Verify Huntarr is installed and running**:

   ```bash
   systemctl --user status huntarr
   podman ps | grep huntarr
   # Should show huntarr container running on port 9705
   ```

2. **Check if Huntarr schedule is configured** (MOST COMMON ISSUE):
   - Navigate to: http://media-services.discus-moth.ts.net:9705
   - Go to **Settings** → **Scheduling**
   - Look at **"Current Schedules"** section
   - **If empty**: Follow [Huntarr Setup Guide](../configuration/huntarr-setup.md) Step 4
   - **If configured**: Verify schedule is running (check "How Long Ago" in Hunt Manager)

3. **Quick Huntarr schedule setup**:
   - Settings → Scheduling
   - Time: 03:00 (3 AM)
   - Frequency: Daily (All Days)
   - Action: Enable
   - App: All Apps (Global)
   - Click "+ Add Schedule"

##### Why Huntarr Matters

- Automatically triggers searches for ALL missing episodes daily
- Works for backlog content that RSS can't catch
- No manual intervention needed once configured
- See [Huntarr Configuration Guide](../configuration/huntarr-setup.md) for full setup

##### Option 2: Manual Bulk Search (One-Time Fix)

For immediate results without Huntarr:

1. Go to **Wanted** → **Missing** in Sonarr
2. Select episodes you want to search for
3. Click "Search Selected" at the top
4. Wait for searches to complete

**Note**: This is manual and must be repeated for new missing episodes. Huntarr automates this.

##### Option 3: Enable Automatic Search on Add (Limited)

- Settings → Media Management
- Enable "Episode Title Required" → Never
- This helps but ONLY works for newly added content, not existing backlog

##### Verification

1. After setting up Huntarr schedule (or manual search):
   - Check Sonarr → Activity → Queue
   - Missing episodes should appear as they're found
   - Downloads start automatically via Prowlarr → Download clients

2. Check Huntarr is working:
   - Huntarr → Main → Hunt Manager
   - Look at "How Long Ago" column (should update after schedule runs)
   - Huntarr → Home dashboard shows "Live Hunts Executed" counter

**See Also**:

- [Huntarr Configuration Guide](../configuration/huntarr-setup.md)
- [Huntarr Troubleshooting](huntarr.md)

---

### 5. Media Import Failures

**Symptoms**:

- Downloads complete but don't import
- Error: "No files found for import"
- Files stuck in download folder

**Diagnosis**:

```bash
# Check folder structure
ls -la /mnt/data/media/tv
ls -la /mnt/data/media/movies
ls -la /mnt/data/torrents/
ls -la /mnt/data/usenet/

# Check permissions
ls -l /mnt/data/

# View activity logs in Sonarr/Radarr
# Dashboard > Activity > Queue
```

**Solutions**:

1. **Wrong path configuration**:
   - Settings > Media Management > Root Folders
   - Should be `/mnt/data/media/tv` (Sonarr) or `/mnt/data/media/movies` (Radarr)

2. **Download client category mismatch**:
   - Sonarr: Settings > Download Clients > Category should be `tv`
   - Radarr: Settings > Download Clients > Category should be `movies`
   - Verify categories exist in qBittorrent/SABnzbd

3. **Permission issues**:

   ```bash
   # Fix NFS permissions
   sudo chown -R 3000:3000 /mnt/data
   sudo chmod -R 775 /mnt/data
   ```

4. **Check container volume mounts**:

   ```bash
   podman inspect sonarr | grep -A 10 Mounts
   # Should show /mnt/data mounted
   ```

### 6. Quality Profile Issues

**Symptoms**:

- Downloads wrong quality (e.g., 720p instead of 1080p)
- "No results found" when searching
- Upgrades not happening

**Diagnosis**:

- Check Settings > Profiles > Quality Profiles
- Verify custom formats (if using Recyclarr)
- Check indexer capabilities in Prowlarr

**Solutions**:

1. **Adjust quality profile**:
   - Settings > Profiles > [Profile Name]
   - Enable desired qualities
   - Set cutoff appropriately

2. **Run Recyclarr sync** (if configured):

   ```bash
   podman exec recyclarr recyclarr sync
   ```

3. **Check indexer search capabilities**:
   - Prowlarr > Indexers > [Indexer]
   - Verify capabilities include required quality terms

4. **Manual search to debug**:
   - Series/Movie > Search icon
   - Check what qualities are available
   - Review rejection reasons

### 7. Metadata/Poster Issues

**Symptoms**:

- Missing posters or artwork
- Incorrect metadata
- "Unknown Series/Movie"

**Diagnosis**:

```bash
# Check metadata provider connectivity
podman exec sonarr wget -O- https://api.thetvdb.com
podman exec radarr wget -O- https://api.themoviedb.org
```

**Solutions**:

1. **Refresh metadata**:
   - Series/Movie > Edit > Refresh & Scan

2. **Check metadata settings**:
   - Settings > Metadata
   - Verify providers are enabled

3. **Re-identify series/movie**:
   - Edit > Search for correct match on TVDB/TMDB

### 8. Disk Space Warnings

**Symptoms**:

- Warning: "Disk space is low"
- Downloads paused due to space
- Import failures

**Diagnosis**:

```bash
# Check disk space
df -h /mnt/data

# Check what's using space
du -sh /mnt/data/*
du -sh /mnt/data/torrents/*
du -sh /mnt/data/media/*
```

**Solutions**:

1. **Clean completed downloads**:
   - If using hardlinks, completed torrents can be removed
   - qBittorrent: Remove completed torrents (files stay in media folder)

2. **Remove old/unwanted media**:
   - Sonarr/Radarr > Series/Movies > Unmonitor + Delete

3. **Check for incomplete downloads**:

   ```bash
   ls -lh /mnt/data/torrents/incomplete
   ls -lh /mnt/data/usenet/incomplete
   ```

4. **Increase NFS storage** (see docs/reference/nas-setup.md)

### 9. API Rate Limiting

**Symptoms**:

- Error: "API rate limit exceeded"
- Slow metadata updates
- Search failures

**Diagnosis**:

- Check Settings > General > Analytics
- Review logs for API errors

**Solutions**:

1. **Reduce refresh intervals**:
   - Settings > Media Management
   - Increase "Rescan Series/Movie Folder" interval

2. **Disable unnecessary features**:
   - Settings > Metadata > Disable unused providers

3. **Wait for rate limit reset**:
   - TVDB/TMDB limits reset hourly/daily

## Advanced Troubleshooting

### Database Corruption

```bash
# Stop services
systemctl --user stop sonarr radarr

# Backup databases
cp -r ~/.config/sonarr ~/.config/sonarr.bak
cp -r ~/.config/radarr ~/.config/radarr.bak

# Restart and check logs
systemctl --user start sonarr radarr
journalctl --user -u sonarr -f
journalctl --user -u radarr -f
```

### Reset Configuration

```bash
# Backup first!
systemctl --user stop sonarr radarr

# Remove config (will reset everything!)
mv ~/.config/sonarr ~/.config/sonarr.old
mv ~/.config/radarr ~/.config/radarr.old

# Restart (will create fresh config)
systemctl --user start sonarr radarr
```

### Container Debugging

```bash
# Enter container shell
podman exec -it sonarr /bin/bash

# Test connectivity
ping -c 3 192.168.0.14
wget -O- http://192.168.0.14:8080

# Check DNS resolution
nslookup download-clients.discus-moth.ts.net

# Exit container
exit
```

### Check Quadlet Configuration

```bash
# View Quadlet files
cat ~/.config/containers/systemd/sonarr.container
cat ~/.config/containers/systemd/radarr.container

# Regenerate systemd units
systemctl --user daemon-reload

# Check generated service
systemctl --user cat sonarr
```

## Getting Help

If issues persist:

1. **Collect logs**:

   ```bash
   journalctl --user -u sonarr -n 500 --no-pager > /tmp/sonarr.log
   journalctl --user -u radarr -n 500 --no-pager > /tmp/radarr.log
   podman logs sonarr --tail 500 >> /tmp/sonarr.log
   podman logs radarr --tail 500 >> /tmp/radarr.log
   ```

2. **Check Servarr Wiki**:
   - Sonarr: https://wiki.servarr.com/sonarr
   - Radarr: https://wiki.servarr.com/radarr

3. **Community Support**:
   - Sonarr Discord: https://discord.gg/M6BvZn5
   - Radarr Discord: https://discord.gg/radarr
   - Reddit: r/sonarr, r/radarr

## See Also

- [Download Clients Troubleshooting](download-clients.md)
- [Prowlarr Troubleshooting](prowlarr.md)
- [Huntarr Troubleshooting](huntarr.md)
- [NAS/NFS Troubleshooting](nas-nfs.md)
- [Podman Troubleshooting](podman.md)
- [Common Issues](common-issues.md)
