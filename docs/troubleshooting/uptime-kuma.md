# Uptime Kuma Troubleshooting

Troubleshooting guide for Uptime Kuma uptime monitoring issues.

> **IMPORTANT**: Uptime Kuma runs as a **rootless Podman container with Quadlet** on Monitoring VM (192.168.10.16).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into Monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# Check Uptime Kuma service status
systemctl --user status uptime-kuma

# View Uptime Kuma logs
journalctl --user -u uptime-kuma -f

# Check web UI access
curl http://localhost:3001

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep uptime-kuma
```

## Common Issues

### 1. Uptime Kuma Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start uptime-kuma.service"
- Container exits immediately

**Diagnosis**:

```bash
# Check service status
systemctl --user status uptime-kuma

# View detailed logs
journalctl --user -u uptime-kuma -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :3001

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs uptime-kuma
```

**Solutions**:

1. **Port 3001 already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :3001
   # Stop the conflicting service
   ```

2. **Permission issues**:

   ```bash
   # Check data directory ownership
   ls -la ~/.config/uptime-kuma/

   # Fix permissions (should be owned by your user)
   chown -R $(whoami):$(whoami) ~/.config/uptime-kuma/
   ```

3. **Database corruption**:

   ```bash
   # Stop Uptime Kuma
   systemctl --user stop uptime-kuma

   # Backup and remove database
   cp ~/.config/uptime-kuma/kuma.db ~/.config/uptime-kuma/kuma.db.bak
   rm ~/.config/uptime-kuma/kuma.db

   # Restart (will create new database)
   systemctl --user start uptime-kuma
   # Reconfigure monitors in Web UI
   ```

4. **Container image issues**:

   ```bash
   # Pull latest image
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull docker.io/louislam/uptime-kuma:latest

   # Restart service
   systemctl --user restart uptime-kuma
   ```

### 2. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://monitoring.discus-moth.ts.net:3001
- Can't reach http://192.168.10.16:3001

**Diagnosis**:

```bash
# Check if Uptime Kuma is running
systemctl --user status uptime-kuma

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:3001

# Check port is listening
sudo netstat -tulpn | grep 3001
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # Allow Uptime Kuma port
   sudo ufw allow from 192.168.10.0/24 to any port 3001
   sudo ufw allow from 100.64.0.0/10 to any port 3001
   sudo ufw reload
   ```

2. **Service not running**:

   ```bash
   systemctl --user start uptime-kuma
   systemctl --user enable uptime-kuma
   ```

3. **Container networking issues**:

   ```bash
   # Check container ports
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman port uptime-kuma

   # Should show: 3001/tcp -> 0.0.0.0:3001
   ```

4. **Tailscale connectivity**:

   ```bash
   # Check Tailscale is running
   tailscale status

   # Test access via Tailscale
   curl http://$(tailscale ip -4):3001
   ```

### 3. Monitors Showing "Down" When Services Are Up

**Symptoms**:

- All monitors showing red/down status
- Services accessible manually but Uptime Kuma can't reach them
- "Connection timeout" or "DNS resolution failed" errors

**Diagnosis**:

```bash
# Check if Uptime Kuma can reach target services
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec uptime-kuma ping -c 3 192.168.30.12   # Jellyfin
podman exec uptime-kuma curl -I http://192.168.30.13:8989   # Sonarr

# Check DNS resolution
podman exec uptime-kuma nslookup jellyfin.discus-moth.ts.net

# View monitor logs in Web UI
# Status Page → [Monitor] → View logs
```

**Solutions**:

1. **Network connectivity issues**:

   ```bash
   # Verify container can reach network
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec uptime-kuma ping -c 3 8.8.8.8

   # Check container network mode
   podman inspect uptime-kuma | grep NetworkMode

   # Restart container
   systemctl --user restart uptime-kuma
   ```

2. **DNS resolution failing**:

   ```bash
   # Test DNS from container
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec uptime-kuma nslookup google.com

   # If failing, configure custom DNS in Quadlet .container file
   nano ~/.config/containers/systemd/uptime-kuma.container
   # Add: Network=host or configure DNS

   systemctl --user daemon-reload
   systemctl --user restart uptime-kuma
   ```

3. **Use IP addresses instead of hostnames**:
   - Edit monitors in Web UI
   - Change hostname to IP address (e.g., `http://192.168.30.13:8989` instead of `http://media-services.discus-moth.ts.net:8989`)
   - Save and test

4. **Timeout too short**:
   - Edit monitor settings
   - Increase timeout from 48s to 60-120s
   - Useful for slow-responding services

5. **Wrong protocol or port**:
   - Verify service URL is correct
   - HTTP vs HTTPS
   - Correct port number

### 4. Notifications Not Sending

**Symptoms**:

- Monitors trigger alerts but no notifications received
- "Failed to send notification" in logs
- Email/Discord/Slack notifications not arriving

**Diagnosis**:

```bash
# Check logs for notification errors
journalctl --user -u uptime-kuma | grep -i "notif\|email\|discord\|slack"

# Test notification in Web UI
# Settings → Notifications → [Notification] → Test
```

**Solutions**:

1. **Notification provider not configured**:
   - Settings → Notifications → Add Notification
   - Configure provider (Email, Discord, Slack, etc.)
   - Assign to monitors

2. **Email notifications failing**:

   Check SMTP settings:
   - SMTP Host: smtp.gmail.com (or your provider)
   - SMTP Port: 587 (TLS) or 465 (SSL)
   - Authentication: Enabled
   - Username/Password: Correct credentials
   - From Address: Valid email

   Common issues:
   - Gmail: Use App Password, not regular password
   - Firewall blocking SMTP ports
   - TLS/SSL mismatch

3. **Discord webhook invalid**:
   - Get webhook URL from Discord: Server Settings → Integrations → Webhooks
   - Copy full webhook URL
   - Paste in Uptime Kuma → Settings → Notifications → Discord Webhook

4. **Notification not assigned to monitor**:
   - Edit monitor
   - Scroll to "Notifications" section
   - Enable desired notification methods
   - Save

5. **Container can't reach notification service**:

   ```bash
   # Test SMTP/webhook connectivity
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec uptime-kuma curl -I https://discord.com
   podman exec uptime-kuma ping -c 3 smtp.gmail.com
   ```

### 5. Status Page Not Accessible

**Symptoms**:

- Can't access public status page
- "404 Not Found" or "Page doesn't exist"
- Status page shows blank

**Diagnosis**:

```bash
# Check if status page is configured
# Web UI → Status Pages → verify page exists

# Check slug/URL
# Should be: http://monitoring.discus-moth.ts.net:3001/status/[slug]

# Check logs
journalctl --user -u uptime-kuma | grep -i "status\|page"
```

**Solutions**:

1. **Status page not created**:
   - Web UI → Status Pages → Add Status Page
   - Configure title and slug
   - Add monitors to display
   - Save

2. **Wrong URL**:
   - Verify slug matches URL
   - Example: Slug "homelab" → `http://monitoring.discus-moth.ts.net:3001/status/homelab`

3. **Public access disabled**:
   - Edit status page
   - Enable "Public" toggle
   - Save

4. **Monitors not added to status page**:
   - Edit status page
   - Add monitors to "Monitors" section
   - Save

### 6. High CPU/Memory Usage

**Symptoms**:

- Uptime Kuma using excessive resources
- System slowdown
- Container frequently restarting

**Diagnosis**:

```bash
# Check resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats uptime-kuma --no-stream

# Check number of monitors
# Web UI → Dashboard → count active monitors

# Check logs for errors
journalctl --user -u uptime-kuma | grep -i "error\|memory"
```

**Solutions**:

1. **Too many monitors**:
   - Reduce number of active monitors
   - Increase check interval (e.g., from 60s to 300s)
   - Disable unused monitors

2. **Check interval too frequent**:
   - Edit monitors
   - Increase "Heartbeat Interval" from 60s to 120-300s
   - Reduces CPU load

3. **Large database**:

   ```bash
   # Check database size
   ls -lh ~/.config/uptime-kuma/kuma.db

   # If very large (>1GB), consider:
   # - Reducing data retention period
   # - Clearing old data
   # - Database optimization
   ```

4. **Restart container to clear memory**:

   ```bash
   systemctl --user restart uptime-kuma
   ```

### 7. Data Loss or Monitors Disappeared

**Symptoms**:

- Previously configured monitors gone
- Status pages disappeared
- Dashboard empty

**Diagnosis**:

```bash
# Check if database exists
ls -la ~/.config/uptime-kuma/kuma.db

# Check database size
du -sh ~/.config/uptime-kuma/

# Check logs for database errors
journalctl --user -u uptime-kuma | grep -i "database\|sqlite"
```

**Solutions**:

1. **Database file deleted or moved**:

   ```bash
   # Check if backup exists
   ls -la ~/.config/uptime-kuma/*.bak
   ls -la ~/.config/uptime-kuma/*.backup

   # Restore from backup
   systemctl --user stop uptime-kuma
   cp ~/.config/uptime-kuma/kuma.db.bak ~/.config/uptime-kuma/kuma.db
   systemctl --user start uptime-kuma
   ```

2. **Database corruption**:

   ```bash
   # Try repair
   systemctl --user stop uptime-kuma
   sqlite3 ~/.config/uptime-kuma/kuma.db "PRAGMA integrity_check;"

   # If corrupted beyond repair, restore from backup or start fresh
   ```

3. **Volume mount issue**:

   ```bash
   # Check volume is mounted correctly
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman inspect uptime-kuma | grep -A 10 Mounts

   # Should show: ~/.config/uptime-kuma -> /app/data
   ```

### 8. SSL/TLS Certificate Errors

**Symptoms**:

- "SSL certificate error" when monitoring HTTPS services
- "Certificate verification failed"
- Can't monitor self-signed certificate services

**Diagnosis**:

```bash
# Check which monitors are failing
# Web UI → Dashboard → look for SSL errors

# Test certificate from container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec uptime-kuma curl -v https://target-service.example.com
```

**Solutions**:

1. **Self-signed certificates**:
   - Edit monitor
   - Enable "Ignore TLS/SSL Error"
   - Save
   - **Warning**: Only use for internal services you trust

2. **Expired certificates**:
   - Renew certificate on target service
   - Or temporarily enable "Ignore TLS/SSL Error"

3. **Certificate chain issues**:
   - Ensure target service has complete certificate chain
   - Include intermediate certificates

## Advanced Troubleshooting

### Database Maintenance

```bash
# Stop Uptime Kuma
systemctl --user stop uptime-kuma

# Backup database
cp ~/.config/uptime-kuma/kuma.db ~/.config/uptime-kuma/kuma.db.backup

# Optimize database
sqlite3 ~/.config/uptime-kuma/kuma.db "VACUUM;"
sqlite3 ~/.config/uptime-kuma/kuma.db "REINDEX;"

# Restart
systemctl --user start uptime-kuma
```

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat uptime-kuma

# View Quadlet .container file
cat ~/.config/containers/systemd/uptime-kuma.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart uptime-kuma
```

### Container Debugging

```bash
# Enter container shell
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it uptime-kuma /bin/sh

# Inside container, test connectivity
ping 8.8.8.8
nslookup google.com
curl http://192.168.30.13:8989   # Test Sonarr

# Exit
exit
```

### Backup and Restore

```bash
# Backup Uptime Kuma data
systemctl --user stop uptime-kuma
tar -czf ~/uptime-kuma-backup-$(date +%Y%m%d).tar.gz ~/.config/uptime-kuma/
systemctl --user start uptime-kuma

# Restore from backup
systemctl --user stop uptime-kuma
rm -rf ~/.config/uptime-kuma/
tar -xzf ~/uptime-kuma-backup-*.tar.gz -C ~/
systemctl --user start uptime-kuma
```

## Best Practices

### Monitor Configuration

1. **Set appropriate check intervals**:
   - Critical services: 60 seconds
   - Standard services: 120-300 seconds
   - Low-priority services: 600 seconds (10 minutes)

2. **Use retry before alerting**:
   - Set "Retries" to 2-3
   - Prevents false alerts from transient network issues

3. **Configure maintenance windows**:
   - Schedule maintenance during updates
   - Prevents alert spam during planned downtime

### Notification Strategy

1. **Group similar monitors**:
   - Use tags to group related services
   - Configure notification groups

2. **Escalation**:
   - First alert: Slack/Discord (low urgency)
   - Persistent down: Email (higher urgency)
   - Critical services: SMS/Phone call

3. **Avoid notification fatigue**:
   - Don't monitor too frequently
   - Use retries before alerting
   - Disable notifications for non-critical services

## Getting Help

If issues persist after trying these solutions:

1. **Collect logs**:

   ```bash
   journalctl --user -u uptime-kuma -n 500 --no-pager > /tmp/uptime-kuma.log
   ```

2. **Enable debug logging**:

   ```bash
   # Set environment variable in Quadlet .container file
   nano ~/.config/containers/systemd/uptime-kuma.container

   # Add under [Container]:
   # Environment=DEBUG=true

   systemctl --user daemon-reload
   systemctl --user restart uptime-kuma
   ```

3. **Gather diagnostic info**:

   ```bash
   # Uptime Kuma version (check Web UI footer)

   # Container status
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman ps -a | grep uptime-kuma
   podman inspect uptime-kuma

   # Database info
   ls -lh ~/.config/uptime-kuma/
   ```

4. **Uptime Kuma community resources**:
   - Official docs: https://github.com/louislam/uptime-kuma/wiki
   - GitHub: https://github.com/louislam/uptime-kuma/issues
   - Reddit: r/UptimeKuma
   - Discord: Check GitHub for invite link

## See Also

- [Uptime Kuma Configuration Guide](../configuration/uptime-kuma-setup.md) - Initial setup instructions
- [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md) - Complete monitoring configuration
- [Networking Troubleshooting](networking.md) - Network connectivity issues
- [Service Endpoints](../configuration/service-endpoints.md) - Uptime Kuma access information
