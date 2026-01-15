# Home Assistant Troubleshooting

Troubleshooting guide for Home Assistant home automation platform issues.

> **IMPORTANT**: Home Assistant runs as a **rootless Podman container with Quadlet**. Use `systemctl --user` and
`journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# Check Home Assistant service status
systemctl --user status home-assistant

# View Home Assistant logs
journalctl --user -u home-assistant -f

# Check if Home Assistant is listening
sudo netstat -tulpn | grep 8123

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep home-assistant
```

## Common Issues

### 1. Home Assistant Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start home-assistant.service"
- Container exits immediately

**Diagnosis**:

```bash
# Check service status
systemctl --user status home-assistant

# View detailed logs
journalctl --user -u home-assistant -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :8123

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs home-assistant
```

**Solutions**:

1. **Port already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :8123
   # Stop the conflicting service
   ```

2. **Permission issues**:

   ```bash
   # Check config directory ownership
   ls -la ~/.config/homeassistant/

   # Fix permissions if needed (should be owned by your user)
   chown -R $(whoami):$(whoami) ~/.config/homeassistant/
   ```

3. **Corrupted configuration**:

   ```bash
   # Check configuration syntax
   journalctl --user -u home-assistant -n 200 | grep -i "error\|invalid"

   # Restore from backup if needed
   systemctl --user stop home-assistant
   cp -r ~/.config/homeassistant/ ~/.config/homeassistant.bak/
   # Restore known good configuration
   systemctl --user start home-assistant
   ```

4. **Container image issues**:

   ```bash
   # Pull latest image
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull ghcr.io/home-assistant/home-assistant:stable

   # Restart service
   systemctl --user restart home-assistant
   ```

### 2. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://home-assistant.discus-moth.ts.net:8123
- Can't reach http://192.168.0.10:8123

**Diagnosis**:

```bash
# Check if Home Assistant is running
systemctl --user status home-assistant

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:8123

# Check if accessible from Tailscale IP
curl http://$(tailscale ip -4):8123
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # Allow Home Assistant port
   sudo ufw allow from 192.168.0.0/24 to any port 8123
   sudo ufw allow from 100.64.0.0/10 to any port 8123
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
   systemctl --user start home-assistant
   systemctl --user enable home-assistant
   ```

4. **Container networking issues**:

   ```bash
   # Check container network mode
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman inspect home-assistant | grep -A 10 NetworkMode

   # Should be "host" network mode
   # If not, regenerate Quadlet config and restart
   systemctl --user daemon-reload
   systemctl --user restart home-assistant
   ```

### 3. Integration/Add-on Installation Failures

**Symptoms**:

- Error: "Failed to install integration"
- Add-on won't install or start
- "Unknown error occurred" during setup

**Diagnosis**:

```bash
# Check logs during installation
journalctl --user -u home-assistant -f

# Check disk space
df -h /home

# Check network connectivity from container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec home-assistant ping -c 3 8.8.8.8
podman exec home-assistant curl -I https://github.com
```

**Solutions**:

1. **Network connectivity issues**:

   ```bash
   # Verify DNS resolution
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec home-assistant nslookup github.com

   # Check if using custom DNS (AdGuard Home)
   # Try temporarily using public DNS
   ```

2. **Insufficient disk space**:

   ```bash
   # Check disk usage
   df -h /home
   du -sh ~/.config/homeassistant/

   # Clean up if needed
   systemctl --user stop home-assistant
   rm -rf ~/.config/homeassistant/tts/
   rm -rf ~/.config/homeassistant/.storage/
   systemctl --user start home-assistant
   ```

3. **Integration dependency issues**:

   ```bash
   # Check Python dependencies in logs
   journalctl --user -u home-assistant | grep -i "requirement\|dependency"

   # Restart Home Assistant to retry dependencies
   systemctl --user restart home-assistant
   ```

4. **Corrupted integration cache**:

   ```bash
   # Stop Home Assistant
   systemctl --user stop home-assistant

   # Clear integration cache
   rm -rf ~/.config/homeassistant/deps/

   # Restart
   systemctl --user start home-assistant
   ```

### 4. Devices Not Discovered

**Symptoms**:

- Auto-discovery not finding devices
- Integrations can't connect to local devices
- "No devices found" during setup

**Diagnosis**:

```bash
# Check if container has access to local network
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec home-assistant ip addr
podman exec home-assistant ip route

# Test device connectivity
podman exec home-assistant ping <device-ip>

# Check for multicast/broadcast (needed for discovery)
# Verify network mode is "host"
podman inspect home-assistant | grep NetworkMode
```

**Solutions**:

1. **Container not using host network**:

   ```bash
   # Verify Quadlet configuration uses host network
   cat ~/.config/containers/systemd/home-assistant.container | grep Network

   # Should have: Network=host
   # If missing, edit .container file and reload
   systemctl --user daemon-reload
   systemctl --user restart home-assistant
   ```

2. **Firewall blocking multicast/discovery**:

   ```bash
   # Allow mDNS/SSDP discovery protocols
   sudo ufw allow from 192.168.0.0/24 to any port 1900 proto udp   # SSDP
   sudo ufw allow from 192.168.0.0/24 to any port 5353 proto udp   # mDNS
   sudo ufw reload
   ```

3. **Manual integration instead of auto-discovery**:
   - Go to Settings → Devices & Services
   - Click "+ ADD INTEGRATION"
   - Search for your device type
   - Manually enter IP address/credentials

4. **Check device is on same network**:
   - Verify device is on 192.168.0.0/24 network
   - Check device is not isolated by router VLAN/guest network

### 5. Database Errors / Performance Issues

**Symptoms**:

- Slow web UI performance
- "Database is locked" errors
- High CPU/memory usage
- Logbook/history not loading

**Diagnosis**:

```bash
# Check Home Assistant resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats home-assistant

# Check database size
ls -lh ~/.config/homeassistant/home-assistant_v2.db

# View database errors in logs
journalctl --user -u home-assistant | grep -i "database\|sqlite"
```

**Solutions**:

1. **Database too large**:

   ```bash
   # Check current recorder settings in configuration.yaml
   cat ~/.config/homeassistant/configuration.yaml | grep -A 10 recorder

   # Edit configuration to reduce retention
   # Add/modify in configuration.yaml:
   # recorder:
   #   purge_keep_days: 7
   #   commit_interval: 30

   # Restart Home Assistant
   systemctl --user restart home-assistant
   ```

2. **Purge old database records**:
   - Navigate to Developer Tools → Services
   - Call service: `recorder.purge`
   - Set `keep_days: 7` (or desired retention)
   - Wait for purge to complete

3. **Database corruption**:

   ```bash
   # Stop Home Assistant
   systemctl --user stop home-assistant

   # Backup database
   cp ~/.config/homeassistant/home-assistant_v2.db ~/.config/homeassistant/home-assistant_v2.db.bak

   # Check database integrity
   sqlite3 ~/.config/homeassistant/home-assistant_v2.db "PRAGMA integrity_check;"

   # If corrupted, restore from backup or start fresh
   # Starting fresh (loses history):
   rm ~/.config/homeassistant/home-assistant_v2.db

   # Restart
   systemctl --user start home-assistant
   ```

4. **Optimize database**:

   ```bash
   # Stop Home Assistant
   systemctl --user stop home-assistant

   # Vacuum database
   sqlite3 ~/.config/homeassistant/home-assistant_v2.db "VACUUM;"

   # Restart
   systemctl --user start home-assistant
   ```

### 6. Authentication/Login Issues

**Symptoms**:

- Can't log in with correct credentials
- "Invalid authentication" errors
- Locked out of Home Assistant

**Diagnosis**:

```bash
# Check authentication logs
journalctl --user -u home-assistant | grep -i "auth\|login"

# Verify user exists in .storage
ls ~/.config/homeassistant/.storage/auth*
```

**Solutions**:

1. **Reset password via CLI**:

   ```bash
   # Enter container
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec -it home-assistant /bin/bash

   # Inside container, change password
   hass --script auth change_password <username>

   # Exit container
   exit
   ```

2. **Disable authentication temporarily** (emergency access):

   ```bash
   # Edit configuration.yaml
   nano ~/.config/homeassistant/configuration.yaml

   # Add (TEMPORARY - remove after fixing):
   # homeassistant:
   #   auth_providers:
   #     - type: trusted_networks
   #       trusted_networks:
   #         - 192.168.0.0/24
   #         - 100.64.0.0/10

   # Restart
   systemctl --user restart home-assistant

   # Access without login, then re-enable authentication
   ```

3. **Delete user and recreate**:

   ```bash
   # Backup authentication files
   systemctl --user stop home-assistant
   cp -r ~/.config/homeassistant/.storage/ ~/.config/homeassistant/.storage.bak/

   # Delete auth files (will require onboarding again)
   rm ~/.config/homeassistant/.storage/auth*

   # Restart and go through onboarding
   systemctl --user start home-assistant
   ```

### 7. Update Failures

**Symptoms**:

- Update doesn't complete
- Home Assistant won't start after update
- "Version mismatch" errors

**Diagnosis**:

```bash
# Check current version
journalctl --user -u home-assistant | grep -i "version"

# Check container image
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman images | grep home-assistant

# Check for update errors
journalctl --user -u home-assistant -n 200 | grep -i "error\|fail"
```

**Solutions**:

1. **Rollback to previous version**:

   ```bash
   # Stop Home Assistant
   systemctl --user stop home-assistant

   # Pull specific stable version
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman pull ghcr.io/home-assistant/home-assistant:2024.1.0  # Replace with known good version

   # Edit Quadlet .container file to pin version
   nano ~/.config/containers/systemd/home-assistant.container
   # Change Image= line to specific version

   # Reload and restart
   systemctl --user daemon-reload
   systemctl --user start home-assistant
   ```

2. **Clear cache after failed update**:

   ```bash
   systemctl --user stop home-assistant

   # Clear Python cache
   rm -rf ~/.config/homeassistant/__pycache__/
   rm -rf ~/.config/homeassistant/deps/

   # Restart
   systemctl --user start home-assistant
   ```

3. **Incompatible custom integration**:

   ```bash
   # Check logs for integration errors
   journalctl --user -u home-assistant | grep -i "custom_component"

   # Temporarily disable custom integrations
   systemctl --user stop home-assistant
   mv ~/.config/homeassistant/custom_components/ ~/.config/homeassistant/custom_components.disabled/
   systemctl --user start home-assistant

   # Update integrations one by one via HACS
   ```

## Advanced Troubleshooting

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat home-assistant

# View Quadlet .container file
cat ~/.config/containers/systemd/home-assistant.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
```

### Container Resource Limits

```bash
# Check current resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats home-assistant --no-stream

# Check configured limits
podman inspect home-assistant | grep -A 5 "Memory\|Cpu"
```

### Network Debugging

```bash
# Enter container shell
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it home-assistant /bin/bash

# Inside container, test connectivity
ping -c 3 8.8.8.8
nslookup home-assistant.io
curl -I https://www.home-assistant.io

# Test local device connectivity
ping <device-ip>

# Exit
exit
```

### Backup and Restore

```bash
# Create full backup
systemctl --user stop home-assistant
tar -czf ~/home-assistant-backup-$(date +%Y%m%d).tar.gz ~/.config/homeassistant/
systemctl --user start home-assistant

# Restore from backup
systemctl --user stop home-assistant
rm -rf ~/.config/homeassistant/
tar -xzf ~/home-assistant-backup-*.tar.gz -C ~/
systemctl --user start home-assistant
```

## Getting Help

If issues persist after trying these solutions:

1. **Check Home Assistant logs**:

   ```bash
   journalctl --user -u home-assistant -n 500 --no-pager > /tmp/home-assistant.log
   ```

2. **Enable debug logging**:

   Edit `~/.config/homeassistant/configuration.yaml`:

   ```yaml
   logger:
     default: info
     logs:
       homeassistant.core: debug
       homeassistant.components: debug
   ```

   Restart: `systemctl --user restart home-assistant`

3. **Gather diagnostic info**:

   ```bash
   # System info
   uname -a
   lsb_release -a

   # Podman version
   podman --version

   # Container status
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman ps -a | grep home-assistant
   podman inspect home-assistant
   ```

4. **Home Assistant community resources**:
   - Official docs: https://www.home-assistant.io/docs/
   - Community forum: https://community.home-assistant.io/
   - GitHub: https://github.com/home-assistant/core/issues
   - Discord: https://discord.gg/home-assistant

## See Also

- [Service Endpoints](../configuration/service-endpoints.md) - Home Assistant access information
- [Networking Troubleshooting](networking.md) - Tailscale and firewall issues
- [Common Issues](common-issues.md) - Cross-service problems
- [Podman Troubleshooting](podman.md) - Container runtime issues
