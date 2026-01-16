# Homarr Troubleshooting

Homarr is a customizable homepage/dashboard for organizing and accessing all your services in one place.

> **IMPORTANT**: Homarr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.0.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: media-services (192.168.0.13)
- **Port**: 7575
- **Container**: homarr
- **Config Path**: `~/.config/homarr/`
- **Deployment**: Rootless Podman with Quadlet
- **Purpose**: Service dashboard and homepage

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:7575
- **Local Network**: http://192.168.0.13:7575

## Quick Diagnostics

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check service status
systemctl --user status homarr

# View logs
journalctl --user -u homarr -f

# Check if container is running
podman ps | grep homarr

# Check resource usage
podman stats homarr --no-stream

# Verify config directory
ls -la ~/.config/homarr/
```

## Common Issues

### 1. Can't Access Homarr Web UI

**Symptoms**:

- Browser shows "Connection refused" or timeout
- Service appears down

**Diagnosis**:

```bash
# Check service status
systemctl --user status homarr

# Check if port is listening
sudo netstat -tulpn | grep 7575

# Check firewall
sudo ufw status | grep 7575
```

**Solutions**:

1. **Service not running**:

   ```bash
   systemctl --user start homarr
   systemctl --user enable homarr

   # Check logs for errors
   journalctl --user -u homarr -n 100
   ```

2. **Port conflict**:

   ```bash
   # Check what's using port 7575
   sudo lsof -i :7575

   # If conflict, stop the other service or change Homarr port
   ```

3. **Firewall blocking**:

   ```bash
   # Allow port 7575 (if needed)
   sudo ufw allow from 192.168.0.0/24 to any port 7575
   sudo ufw allow from 100.64.0.0/10 to any port 7575
   sudo ufw reload
   ```

### 2. Dashboard Not Loading Correctly

**Symptoms**:

- Page loads but tiles are empty
- Services show as offline when they're running
- Icons not displaying

**Diagnosis**:

```bash
# Check Homarr logs for errors
journalctl --user -u homarr | grep -i error

# Check container health
podman inspect homarr | grep -A 10 Health
```

**Solutions**:

1. **Clear browser cache**:
   - Hard refresh: Ctrl+Shift+R (or Cmd+Shift+R on Mac)
   - Clear site data in browser settings

2. **Service integration issues**:
   - Verify service URLs are correct in Homarr settings
   - Use internal hostnames: `http://localhost:8989` for Sonarr, etc.
   - For services on other VMs, use Tailscale hostname or IP

3. **Icon loading issues**:
   - Check if icon URLs are accessible
   - Use built-in icons when possible
   - Check network connectivity from container

### 3. Services Showing Offline

**Symptoms**:

- Services show red/offline status
- Ping checks failing
- API integrations not working

**Diagnosis**:

```bash
# Test connectivity from Homarr container
podman exec homarr curl -s http://localhost:8989 | head -5  # Sonarr
podman exec homarr curl -s http://localhost:7878 | head -5  # Radarr

# Check DNS resolution
podman exec homarr nslookup media-services.discus-moth.ts.net
```

**Solutions**:

1. **Incorrect service URLs**:
   - For same-VM services: Use `http://localhost:<port>`
   - For other VMs: Use Tailscale hostname or IP address
   - Don't use container names (Homarr uses host networking)

2. **API key issues**:
   - Verify API keys are correct for each integration
   - Re-copy API keys from service settings

3. **Network mode**:
   - Homarr should use host networking via Quadlet
   - Check: `cat ~/.config/containers/systemd/homarr.container | grep Network`

### 4. Configuration Not Saving

**Symptoms**:

- Changes lost after restart
- Settings reverting to defaults
- "Failed to save" errors

**Diagnosis**:

```bash
# Check config directory permissions
ls -la ~/.config/homarr/

# Check container volume mounts
cat ~/.config/containers/systemd/homarr.container | grep -i volume

# Check disk space
df -h ~/.config/homarr/
```

**Solutions**:

1. **Permission issues**:

   ```bash
   # Fix config directory permissions
   chown -R $(id -u):$(id -g) ~/.config/homarr
   chmod -R 755 ~/.config/homarr
   ```

2. **Volume mount missing**:
   - Verify Quadlet file has correct volume mapping
   - Config should be persisted to `~/.config/homarr/`

3. **Disk space full**:

   ```bash
   # Check available space
   df -h ~/.config

   # Clean up if needed
   podman system prune
   ```

### 5. Slow Performance

**Symptoms**:

- Dashboard loads slowly
- High CPU usage
- Unresponsive interface

**Diagnosis**:

```bash
# Check resource usage
podman stats homarr --no-stream

# Check system resources
free -h
top -p $(pgrep -f homarr)
```

**Solutions**:

1. **Too many services configured**:
   - Reduce number of tiles/integrations
   - Increase refresh intervals for status checks

2. **Memory constraints**:
   - Check VM has sufficient RAM
   - Reduce other service memory usage

3. **Container resource limits**:

   ```bash
   # Check if limits are set in Quadlet file
   cat ~/.config/containers/systemd/homarr.container | grep -i memory
   ```

### 6. Container Won't Start

**Symptoms**:

- Service fails to start
- Exit code non-zero
- Immediate crash after start

**Diagnosis**:

```bash
# Check service status
systemctl --user status homarr

# Check recent logs
journalctl --user -u homarr -n 200

# Check container exit code
podman inspect homarr | grep -i exitcode
```

**Solutions**:

1. **Image pull failure**:

   ```bash
   # Pull latest image
   podman pull ghcr.io/ajnart/homarr:latest

   # Restart service
   systemctl --user restart homarr
   ```

2. **Corrupted config**:

   ```bash
   # Backup and reset config
   mv ~/.config/homarr ~/.config/homarr.bak
   mkdir -p ~/.config/homarr

   # Restart service
   systemctl --user restart homarr
   ```

3. **Port already in use**:

   ```bash
   # Check what's using port 7575
   sudo lsof -i :7575

   # Stop conflicting service
   ```

## Service Integrations

### Adding Service Tiles

1. **Open Homarr settings** (gear icon)
2. **Add new tile** → Select service type
3. **Configure**:
   - Name: Service display name
   - URL: Service URL (use localhost for same-VM)
   - Icon: Built-in or custom URL
   - Integration: Enable for API features

### Common Integration URLs

For services on media-services VM (same as Homarr):

| Service | URL | Port |
|---------|-----|------|
| Sonarr | `http://localhost:8989` | 8989 |
| Radarr | `http://localhost:7878` | 7878 |
| Prowlarr | `http://localhost:9696` | 9696 |
| Jellyseerr | `http://localhost:5055` | 5055 |
| Bazarr | `http://localhost:6767` | 6767 |
| Huntarr | `http://localhost:9705` | 9705 |
| Flaresolverr | `http://localhost:8191` | 8191 |

For services on other VMs:

| Service | URL |
|---------|-----|
| Jellyfin | `http://jellyfin.discus-moth.ts.net:8096` |
| qBittorrent | `http://download-clients.discus-moth.ts.net:8080` |
| SABnzbd | `http://download-clients.discus-moth.ts.net:8081` |
| Prometheus | `http://monitoring.discus-moth.ts.net:9090` |
| Grafana | `http://monitoring.discus-moth.ts.net:3000` |

## Backup and Restore

### Backup Configuration

```bash
# Create backup
tar -czf ~/homarr-backup-$(date +%Y%m%d).tar.gz -C ~/.config homarr

# Copy to safe location
cp ~/homarr-backup-*.tar.gz /mnt/data/backups/
```

### Restore Configuration

```bash
# Stop service
systemctl --user stop homarr

# Restore backup
tar -xzf ~/homarr-backup-YYYYMMDD.tar.gz -C ~/.config/

# Start service
systemctl --user start homarr
```

## Update Homarr

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest image
podman pull ghcr.io/ajnart/homarr:latest

# Restart service
systemctl --user restart homarr

# Check version
journalctl --user -u homarr | grep -i version
```

## Logs and Debugging

### View Logs

```bash
# Real-time logs
journalctl --user -u homarr -f

# Last 100 lines
journalctl --user -u homarr -n 100

# Save to file
journalctl --user -u homarr --no-pager > ~/homarr-logs.txt
```

### Log Patterns

**Successful Start**:

```text
[INFO] Starting Homarr
[INFO] Server listening on port 7575
```

**Integration Error**:

```text
[WARN] Failed to fetch data from service
[ERROR] Connection refused
```

## See Also

- [Service Endpoints](../configuration/service-endpoints.md)
- [Common Issues](common-issues.md)
- [Media Services Workflow](../reference/media-services-workflow.md)
