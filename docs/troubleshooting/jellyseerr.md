# Jellyseerr Troubleshooting

Common issues and solutions for Jellyseerr request management.

> **IMPORTANT**: Jellyseerr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.0.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Quick Diagnostics

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check service status
systemctl --user status jellyseerr

# View logs
journalctl --user -u jellyseerr -f

# Check if container is running
podman ps | grep jellyseerr

# Check resource usage
podman stats jellyseerr --no-stream

# Verify config directory
ls -la ~/.config/jellyseerr/
```

## Common Issues

### 1. Can't Access Jellyseerr Web UI

**Symptoms**:

- Browser shows "Connection refused" or timeout
- Service appears down

**Diagnosis**:

```bash
# Check service status
systemctl --user status jellyseerr

# Check if port is listening
sudo netstat -tulpn | grep 5055

# Check firewall
sudo ufw status | grep 5055
```

**Solutions**:

1. **Service not running**:

   ```bash
   systemctl --user start jellyseerr
   systemctl --user enable jellyseerr

   # Check logs for errors
   journalctl --user -u jellyseerr -n 100
   ```

2. **Port conflict**:

   ```bash
   # Check what's using port 5055
   sudo lsof -i :5055

   # If conflict, stop the other service or change Jellyseerr port
   ```

3. **Firewall blocking**:

   ```bash
   # Allow port 5055 (if needed)
   sudo ufw allow 5055/tcp
   ```

### 2. Cannot Connect to Jellyfin

**Symptoms**:

- "Failed to connect to Jellyfin" error during setup
- Jellyfin test fails in settings

**Diagnosis**:

```bash
# Test Jellyfin connectivity from media-services VM
curl http://jellyfin.discus-moth.ts.net:8096/health
# or
curl http://192.168.0.12:8096/health

# Should return: {"status":"Healthy"}
```

**Solutions**:

1. **Wrong Jellyfin URL**:
   - Use internal network address: `http://192.168.0.12:8096`
   - Or Tailscale hostname: `http://jellyfin.discus-moth.ts.net:8096`
   - **Don't use** `localhost` or `127.0.0.1`

2. **Jellyfin not running**:

   ```bash
   # SSH to Jellyfin VM
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

   # Check status (Jellyfin is a native service, NOT Docker)
   sudo systemctl status jellyfin
   sudo journalctl -u jellyfin -n 50
   ```

3. **Network connectivity**:

   ```bash
   # From media-services VM, ping Jellyfin
   ping jellyfin.discus-moth.ts.net
   ping 192.168.0.12
   ```

4. **Jellyfin API authentication**:
   - Verify admin credentials are correct
   - Check Jellyfin → Dashboard → Users that admin account is active

### 3. Cannot Connect to Sonarr/Radarr

**Symptoms**:

- "Failed to connect" when testing Sonarr/Radarr
- API test fails
- Requests don't send to Sonarr/Radarr

**Diagnosis**:

```bash
# Test Sonarr API
curl -H "X-Api-Key: YOUR_SONARR_API_KEY" \
  http://192.168.0.13:8989/api/v3/system/status

# Test Radarr API
curl -H "X-Api-Key: YOUR_RADARR_API_KEY" \
  http://192.168.0.13:7878/api/v3/system/status
```

**Solutions**:

1. **Wrong API Key**:
   - Get correct API key from Sonarr/Radarr
   - Sonarr: Settings → General → Security → API Key
   - Radarr: Settings → General → Security → API Key
   - Copy/paste carefully (no extra spaces)

2. **Wrong URL**:
   - Use: `http://192.168.0.13:8989` for Sonarr
   - Use: `http://192.168.0.13:7878` for Radarr
   - Or Tailscale: `http://media-services.discus-moth.ts.net:8989`
   - **Don't include** `/api` in the base URL

3. **Authentication disabled in Sonarr/Radarr**:
   - Sonarr/Radarr require authentication to be enabled
   - Check Settings → General → Authentication → Form (recommended)

4. **Root folder doesn't exist**:
   - Verify path: `/data/media/tv` (Sonarr) or `/data/media/movies` (Radarr)
   - Check in Sonarr/Radarr Settings → Media Management → Root Folders

### 4. Requests Not Sending to Sonarr/Radarr

**Symptoms**:

- Requests approved but don't appear in Sonarr/Radarr
- No error shown in Jellyseerr

**Diagnosis**:

```bash
# Check Jellyseerr logs
journalctl --user -u jellyseerr | grep -i sonarr
journalctl --user -u jellyseerr | grep -i radarr
journalctl --user -u jellyseerr | grep -i error

# Check Sonarr/Radarr logs
journalctl --user -u sonarr | grep -i jellyseerr
journalctl --user -u radarr | grep -i jellyseerr
```

**Solutions**:

1. **Enable automatic sending**:
   - Settings → Services → Sonarr/Radarr
   - Check "Enable Scan" and "Enable Automatic Search"

2. **Quality profile missing**:
   - Verify quality profile exists in Sonarr/Radarr
   - Settings → Services → Select valid quality profile

3. **Root folder issue**:
   - Verify root folder in Jellyseerr matches Sonarr/Radarr
   - Check folder permissions

4. **Manual retry**:
   - Go to Requests tab
   - Find failed request
   - Click "Retry" button

### 5. Jellyfin Library Sync Issues

**Symptoms**:

- New media not showing as "Available" in Jellyseerr
- Jellyseerr shows media as "Unavailable" even though it's in Jellyfin

**Diagnosis**:

```bash
# Check last sync time in Jellyseerr
# Settings → Jellyfin → Last Sync

# Check Jellyfin library scan status
# Jellyfin Dashboard → Scheduled Tasks → Scan Media Library
```

**Solutions**:

1. **Manual sync**:
   - Jellyseerr → Settings → Jellyfin → "Sync Libraries" button
   - Wait for sync to complete (may take several minutes for large libraries)

2. **Automatic sync not working**:
   - Settings → Jellyfin → "Enable Jellyfin Library Scan"
   - Set sync interval (default: 6 hours)

3. **Wrong libraries selected**:
   - Settings → Jellyfin → "Libraries"
   - Ensure correct libraries are checked (Movies, TV Shows)

4. **Jellyfin library incomplete**:
   - Check Jellyfin has finished scanning library
   - Jellyfin → Dashboard → Scheduled Tasks → Scan Media Library

### 6. Notifications Not Working

**Symptoms**:

- Users not receiving request status notifications
- Email/Discord notifications failing

**Diagnosis**:

```bash
# Check Jellyseerr logs for notification errors
journalctl --user -u jellyseerr | grep -i notification
journalctl --user -u jellyseerr | grep -i email
journalctl --user -u jellyseerr | grep -i discord
```

**Solutions**:

1. **Email not configured**:
   - Settings → Notifications → Email
   - Enable Email Agent
   - Configure SMTP settings (host, port, username, password)
   - Test email connection

2. **Discord webhook invalid**:
   - Verify webhook URL is correct
   - Test webhook in Discord server settings
   - Check webhook hasn't been deleted

3. **Notifications not enabled for event**:
   - Settings → Notifications → [Agent]
   - Check boxes for desired events:
     - Request Pending
     - Request Approved
     - Request Available
     - Request Failed
     - etc.

4. **User email missing**:
   - Settings → Users → [User]
   - Verify email address is set
   - User must have valid email for email notifications

### 7. Users Can't Sign In

**Symptoms**:

- User credentials not working
- "Invalid credentials" error

**Solutions**:

1. **Use Jellyfin credentials**:
   - Users must sign in with Jellyfin username/password
   - Credentials must match Jellyfin exactly

2. **Jellyfin user import not complete**:
   - Settings → Users → "Import Users from Jellyfin"
   - Wait for import to complete

3. **User disabled in Jellyfin**:
   - Check Jellyfin → Dashboard → Users
   - Ensure user is not disabled

4. **Local user vs Jellyfin user conflict**:
   - Settings → Users
   - Check if user is marked as "Local" vs "Jellyfin"
   - Delete local user and re-import from Jellyfin if needed

### 8. Database Corruption

**Symptoms**:

- Jellyseerr won't start
- Errors about database in logs
- Settings/requests disappearing

**Diagnosis**:

```bash
# Check logs for database errors
journalctl --user -u jellyseerr | grep -i database
journalctl --user -u jellyseerr | grep -i sqlite

# Check database file
ls -lah ~/.config/jellyseerr/db/
```

**Solutions**:

1. **Restore from backup**:

   ```bash
   # Stop Jellyseerr
   systemctl --user stop jellyseerr

   # Restore backup (if available)
   tar -xzf jellyseerr-config-backup-YYYYMMDD.tar.gz \
     -C ~/.config/jellyseerr/

   # Start Jellyseerr
   systemctl --user start jellyseerr
   ```

2. **Repair database** (advanced):

   ```bash
   # Stop Jellyseerr
   systemctl --user stop jellyseerr

   # Install sqlite3
   sudo apt install sqlite3

   # Check database integrity
   sqlite3 ~/.config/jellyseerr/db/db.sqlite3 "PRAGMA integrity_check;"

   # If corrupted, try to recover
   sqlite3 ~/.config/jellyseerr/db/db.sqlite3 ".recover" > recovered.sql

   # Recreate database from recovered SQL (complex - restore from backup preferred)
   ```

3. **Fresh start** (last resort):

   ```bash
   # Backup old config
   mv ~/.config/jellyseerr ~/.config/jellyseerr.old

   # Restart Jellyseerr (will initialize fresh)
   systemctl --user restart jellyseerr

   # Reconfigure from scratch
   ```

### 9. High Memory Usage

**Symptoms**:

- Jellyseerr using excessive RAM
- Container getting killed by OOM

**Diagnosis**:

```bash
# Check memory usage
podman stats jellyseerr --no-stream

# Check logs for memory errors
journalctl --user -u jellyseerr | grep -i memory
```

**Solutions**:

1. **Large library**:
   - Normal for libraries with 10,000+ items
   - Consider increasing VM RAM if needed

2. **Memory leak**:
   - Restart service: `systemctl --user restart jellyseerr`
   - Update to latest version

3. **Reduce sync frequency**:
   - Settings → Jellyfin
   - Increase sync interval to reduce memory pressure

## Performance Optimization

### Speed Up Search

1. Ensure Jellyfin is responding quickly
2. Consider reducing TMDB API rate limits if hitting rate limits

### Reduce Resource Usage

1. Increase library sync interval (Settings → Jellyfin)
2. Disable unused notification agents
3. Limit number of simultaneous requests processed

## Logs and Debugging

### Enable Debug Logging

```bash
# Edit Quadlet container file
nano ~/.config/containers/systemd/jellyseerr.container
# Add to [Container] section:
# Environment=LOG_LEVEL=debug

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart jellyseerr

# View detailed logs
journalctl --user -u jellyseerr -f
```

### Common Log Errors

**"ECONNREFUSED"**: Cannot connect to specified service (Jellyfin/Sonarr/Radarr)

- Check URL and port
- Verify service is running

**"Unauthorized"**: Invalid API key or credentials

- Verify API keys are correct
- Check authentication is enabled

**"SQLITE_BUSY"**: Database locked

- Usually transient, will resolve automatically
- If persistent, restart container

## See Also

- [Jellyseerr Setup Guide](../configuration/jellyseerr-setup.md)
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Jellyfin Troubleshooting](jellyfin.md)
- [Common Issues](common-issues.md)
