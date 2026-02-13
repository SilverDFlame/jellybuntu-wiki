# Huntarr Troubleshooting

Troubleshooting guide for Huntarr missing content discovery issues.

> **IMPORTANT**: Huntarr runs as a **rootless Podman container with Quadlet** on Media Services VM (192.168.30.13).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into Media Services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check Huntarr service status
systemctl --user status huntarr

# View Huntarr logs
journalctl --user -u huntarr -f

# Check web UI access
curl http://localhost:9705

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep huntarr
```

## Common Issues

### 1. Huntarr Not Searching Automatically (MOST COMMON)

**Symptoms**:

- Missing episodes not being found automatically
- No searches happening on schedule
- Manual searches work but automatic ones don't
- "How Long Ago" column in Hunt Manager never updates

**Diagnosis**:

```bash
# Check if schedule is configured (in Web UI)
# Navigate to: Settings → Scheduling
# Look at "Current Schedules" section at the bottom

# Check logs for scheduled runs
journalctl --user -u huntarr | grep -i "schedule\|hunt\|search"
```

**Solutions**:

**This is the #1 most common Huntarr issue!** Huntarr does NOT come with a default schedule configured.

1. **Configure automatic schedule** (REQUIRED):
   - Access Web UI: http://media-services.discus-moth.ts.net:9705
   - Go to **Settings** → **Scheduling**
   - In "Add New Schedule" section:
     - **Time**: `03:00` (3 AM, or your preferred time)
     - **Frequency**: Click **"Daily (All Days)"**
     - **Action**: Select **"Enable"**
     - **App**: Select **"All Apps (Global)"**
   - Click **"+ Add Schedule"**
   - Verify schedule appears in **"Current Schedules"** below

2. **Why this matters**:
   - RSS feeds in Sonarr/Radarr only catch NEW releases (last 24-48 hours)
   - Backlog episodes from older series (2020 and earlier) are NOT in RSS feeds
   - Huntarr's scheduled searches actively query for missing content
   - Without a schedule, Huntarr only runs when manually triggered

3. **Verify schedule is working**:
   - After next scheduled run, check **Main** → **Hunt Manager**
   - Look at **"How Long Ago"** column - should update after schedule runs
   - Check **Home** dashboard for **"Live Hunts Executed"** counter

**Prevention**:

- After initial Huntarr setup, ALWAYS configure a schedule
- See [Huntarr Configuration Guide Step 4](../configuration/huntarr-setup.md#4-configure-automatic-scheduling-critical)

### 2. Huntarr Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start huntarr.service"
- Container exits immediately

**Diagnosis**:

```bash
# Check service status
systemctl --user status huntarr

# View detailed logs
journalctl --user -u huntarr -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :9705

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs huntarr
```

**Solutions**:

1. **Port 9705 already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :9705
   # Stop the conflicting service
   ```

2. **Permission issues**:

   ```bash
   # Check config directory ownership
   ls -la ~/.config/huntarr/

   # Fix permissions (should be owned by your user)
   chown -R $(whoami):$(whoami) ~/.config/huntarr/
   ```

3. **Database corruption**:

   ```bash
   # Stop Huntarr
   systemctl --user stop huntarr

   # Backup and remove database
   cp -r ~/.config/huntarr/data/ ~/.config/huntarr/data.bak/
   rm -rf ~/.config/huntarr/data/

   # Restart (will create new database)
   systemctl --user start huntarr
   # Reconfigure Sonarr/Radarr connections in Web UI
   ```

4. **Container image issues**:

   ```bash
   # Pull latest image
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull ghcr.io/huntarr/huntarr:latest

   # Restart service
   systemctl --user restart huntarr
   ```

### 3. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://media-services.discus-moth.ts.net:9705
- Can't reach http://192.168.30.13:9705

**Diagnosis**:

```bash
# Check if Huntarr is running
systemctl --user status huntarr

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:9705

# Check port is listening
sudo netstat -tulpn | grep 9705
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # Allow Huntarr port
   sudo ufw allow from 192.168.30.0/24 to any port 9705
   sudo ufw allow from 100.64.0.0/10 to any port 9705
   sudo ufw reload
   ```

2. **Service not running**:

   ```bash
   systemctl --user start huntarr
   systemctl --user enable huntarr
   ```

3. **Container networking issues**:

   ```bash
   # Check container ports
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman port huntarr

   # Should show: 9705/tcp -> 0.0.0.0:9705
   ```

### 4. Can't Connect to Sonarr/Radarr

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
podman exec huntarr curl http://localhost:8989
podman exec huntarr curl http://localhost:7878
```

**Solutions**:

1. **Wrong hostname configuration**:
   - Use `localhost` (containers on same VM)
   - NOT Tailscale hostname (media-services.discus-moth.ts.net)
   - NOT `127.0.0.1` (use `localhost` instead)

2. **Incorrect API keys**:
   - Get Sonarr API: Sonarr → Settings → General → Security → API Key
   - Get Radarr API: Radarr → Settings → General → Security → API Key
   - Update in Huntarr → Settings → Sonarr/Radarr

3. **Sonarr/Radarr not running**:

   ```bash
   systemctl --user status sonarr
   systemctl --user status radarr
   systemctl --user start sonarr radarr
   ```

4. **Base URL mismatch**:
   - In Huntarr settings, Base URL should be empty
   - Unless Sonarr/Radarr have custom base URL configured

5. **SSL/HTTPS incorrectly enabled**:
   - Verify "Use SSL" is DISABLED (localhost doesn't use HTTPS)

### 5. No Missing Content Found

**Symptoms**:

- Huntarr finds zero missing episodes/movies
- Dashboard shows "No content found"
- Searches complete but nothing discovered

**Diagnosis**:

```bash
# Check if schedule is configured (see Issue #1)
# Settings → Scheduling → verify schedule exists

# Check logs during search
journalctl --user -u huntarr -f
# Trigger manual search from Web UI and watch logs

# Verify Sonarr/Radarr connection
# Settings → Sonarr/Radarr → Test connection
```

**Solutions**:

1. **No schedule configured**:
   - See Issue #1 above
   - Configure daily schedule in Settings → Scheduling

2. **Search settings too restrictive**:
   - Settings → Search (if available)
   - Reduce "Minimum Score" from 85% to 70%
   - Increase "Search Depth" from Low to Medium or High
   - Enable more discovery options:
     - Find Missing Episodes: ✅
     - Find Sequels/Prequels: ✅
     - Find Franchise Content: ✅

3. **All content already downloaded**:
   - Verify in Sonarr/Radarr that there are actually missing episodes
   - Sonarr → Wanted → Missing
   - Radarr → Missing

4. **Library not synced**:
   - Settings → Sonarr/Radarr → Full Sync
   - Wait for sync to complete
   - Check Dashboard for library count

5. **Filters excluding content**:
   - Check quality profile settings
   - Verify monitored/unmonitored filters
   - Review any custom exclusions

### 6. Too Much Unwanted Content Added

**Symptoms**:

- Huntarr adding hundreds of movies/shows
- Unwanted franchise content appearing
- Storage filling up with unexpected media

**Diagnosis**:

```bash
# Check what's being added
# Web UI → Discovered Content → review list

# Check discovery settings
# Settings → Search → review enabled options
```

**Solutions**:

1. **Disable aggressive discovery**:
   - Settings → Search
   - Disable "Find Similar Content" (can be overwhelming)
   - Disable "Find Franchise Content" (adds all franchise entries)
   - Disable "Find Actor Collections"
   - Keep only "Find Missing Episodes" and "Find Sequels/Prequels"

2. **Increase minimum match score**:
   - Settings → Search
   - Increase "Minimum Score" to 85-90%
   - Higher score = stricter matching

3. **Disable auto-add**:
   - Settings → Search
   - Disable "Auto-Add to Monitored"
   - Manually review and approve suggestions

4. **Use ignore/skip actions**:
   - Discovered Content → Review each item
   - Use "Ignore Forever" for unwanted content
   - Use "Skip" for one-time dismissal

### 7. Searches Take Too Long or Timeout

**Symptoms**:

- Searches never complete
- "Timeout" errors in logs
- High CPU usage during searches

**Diagnosis**:

```bash
# Check resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats huntarr --no-stream

# Check for timeout errors
journalctl --user -u huntarr | grep -i "timeout\|error"
```

**Solutions**:

1. **Reduce search depth**:
   - Settings → Search
   - Change "Search Depth" to "Low"
   - This speeds up searches at cost of thoroughness

2. **Reduce concurrent operations**:
   - Limit number of series/movies processed per run
   - Increase search interval (run less frequently)

3. **Restart stuck search**:

   ```bash
   systemctl --user restart huntarr
   ```

4. **Check Sonarr/Radarr performance**:

   ```bash
   # Verify Sonarr/Radarr are responsive
   systemctl --user status sonarr radarr
   curl -w "@%{time_total}\n" http://localhost:8989
   ```

### 8. Searches Not Triggering in Sonarr/Radarr

**Symptoms**:

- Huntarr finds missing content
- Missing items don't appear in Sonarr/Radarr
- No downloads starting

**Diagnosis**:

```bash
# Check if content was actually added
# Sonarr → Series → look for newly added series
# Radarr → Movies → look for newly added movies

# Check Huntarr logs for API calls
journalctl --user -u huntarr | grep -i "add\|api"
```

**Solutions**:

1. **Auto-add disabled**:
   - Settings → Search
   - Enable "Auto-Add to Monitored"
   - Or manually add from Discovered Content section

2. **Quality profile mismatch**:
   - Huntarr → Settings → Quality
   - Verify default profiles match Sonarr/Radarr
   - Check that profiles exist in Sonarr/Radarr

3. **Sonarr/Radarr API permissions**:
   - Verify API keys have write permissions
   - Test adding content manually in Sonarr/Radarr

4. **Check Sonarr/Radarr for errors**:

   ```bash
   journalctl --user -u sonarr | tail -50
   journalctl --user -u radarr | tail -50
   ```

## Advanced Troubleshooting

### Database Reset

```bash
# Stop Huntarr
systemctl --user stop huntarr

# Backup data
cp -r ~/.config/huntarr/ ~/.config/huntarr.backup/

# Remove database (loses all settings and history!)
rm -rf ~/.config/huntarr/data/

# Restart (will require reconfiguration)
systemctl --user start huntarr
```

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat huntarr

# View Quadlet .container file
cat ~/.config/containers/systemd/huntarr.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart huntarr
```

### Manual Search Testing

```bash
# Access Huntarr container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it huntarr /bin/sh

# Test Sonarr API connectivity
wget -O- http://localhost:8989/api/v3/system/status?apikey=YOUR_API_KEY

# Test Radarr API connectivity
wget -O- http://localhost:7878/api/v3/system/status?apikey=YOUR_API_KEY

# Exit
exit
```

### Verify Schedule Execution

```bash
# Check cron/scheduler logs
journalctl --user -u huntarr | grep -i "schedule\|cron\|task"

# Verify scheduled tasks are in database
# (Check Web UI → Settings → Scheduling → Current Schedules)

# Manually trigger search from Web UI
# Dashboard → Manual Hunt button
```

### Backup and Restore

```bash
# Backup Huntarr configuration
systemctl --user stop huntarr
tar -czf ~/huntarr-backup-$(date +%Y%m%d).tar.gz ~/.config/huntarr/
systemctl --user start huntarr

# Restore from backup
systemctl --user stop huntarr
rm -rf ~/.config/huntarr/
tar -xzf ~/huntarr-backup-*.tar.gz -C ~/
systemctl --user start huntarr
```

## Performance Tuning

### For Large Libraries (1000+ items)

1. **Reduce search frequency**:
   - Schedule: Every 2-3 days instead of daily
   - Gives more time between intensive scans

2. **Lower search depth**:
   - Settings → Search → Search Depth: Low
   - Faster but less thorough

3. **Disable resource-intensive features**:
   - Disable "Find Similar Content"
   - Disable "Find Actor Collections"

### For Small Libraries (< 200 items)

1. **Increase thoroughness**:
   - Search Depth: High
   - Enable all discovery options
   - Lower minimum score to 60-70%

2. **Run searches more frequently**:
   - Schedule: Twice daily (e.g., 3 AM and 3 PM)

## Getting Help

If issues persist after trying these solutions:

1. **Collect logs**:

   ```bash
   journalctl --user -u huntarr -n 500 --no-pager > /tmp/huntarr.log
   ```

2. **Enable debug logging** (if available):
   - Settings → General → Log Level: Debug
   - Restart: `systemctl --user restart huntarr`
   - Check logs: `journalctl --user -u huntarr -f`

3. **Gather diagnostic info**:

   ```bash
   # Huntarr version
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec huntarr cat /app/version.txt   # Or check Web UI footer

   # Container status
   podman ps -a | grep huntarr
   podman inspect huntarr
   ```

4. **Huntarr community resources**:
   - GitHub: https://github.com/Huntarr/Huntarr/issues
   - Discord: Check Huntarr GitHub for invite link
   - Reddit: r/sonarr, r/radarr (related communities)

## See Also

- [Huntarr Configuration Guide](../configuration/huntarr-setup.md) - Complete setup instructions with scheduling
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md) - Connection and search issues
- [Service Endpoints](../configuration/service-endpoints.md) - Huntarr access information
- [Common Issues](common-issues.md) - Cross-service problems
