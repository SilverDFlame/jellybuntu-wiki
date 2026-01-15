# Podman Troubleshooting

Troubleshooting guide for rootless Podman and Quadlet systemd integration.

## Quick Checks

> **Note**: Rootless Podman requires `XDG_RUNTIME_DIR` to locate the user's runtime directory. When SSHing in,
> this variable may not be set. The export below ensures commands work correctly.

```bash
# Set runtime dir for SSH sessions
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Check Podman service (rootless)
systemctl --user status podman.socket

# List running containers
podman ps

# View all containers (including stopped)
podman ps -a

# Check Podman logs
journalctl --user -u podman -n 50

# Check Podman version
podman --version
```

## Common Issues

### 1. Podman Commands Fail with Permission Error

**Symptoms**:

- `podman ps` fails with "permission denied" or "could not get runtime"
- "XDG_RUNTIME_DIR not set" errors
- Commands work as root but not as ansible user

**Diagnosis**:

```bash
# Check if XDG_RUNTIME_DIR is set
echo $XDG_RUNTIME_DIR

# Check if user session is active
loginctl show-user ansible

# Check if lingering is enabled
ls /var/lib/systemd/linger/
```

**Solutions**:

1. **Set XDG_RUNTIME_DIR**:

   ```bash
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   ```

2. **Enable user lingering** (persists user services after logout):

   ```bash
   sudo loginctl enable-linger ansible
   ```

3. **Verify runtime directory exists**:

   ```bash
   ls -la /run/user/$(id -u)/
   ```

### 2. Container Won't Start

**Symptoms**:

- `systemctl --user start container-name` fails
- Container immediately exits
- "Error: container X not found"

**Diagnosis**:

```bash
# Check Quadlet service status
systemctl --user status CONTAINER_NAME

# View service logs
journalctl --user -u CONTAINER_NAME -n 100

# Check container status
podman ps -a | grep CONTAINER_NAME

# View container logs
podman logs CONTAINER_NAME --tail 100
```

**Solutions**:

1. **Port already in use**:

   ```bash
   # Find what's using the port
   sudo ss -tlnp | grep :PORT_NUMBER

   # Stop conflicting service or change port
   ```

2. **Permission issues on volumes**:

   ```bash
   # Check volume mount permissions
   ls -la /path/to/mounted/volume

   # For NFS mounts (use nfsuser 3000:3000)
   sudo chown -R 3000:3000 /path/to/mounted/volume

   # For local mounts (use ansible user)
   sudo chown -R ansible:ansible /opt/service-name
   ```

3. **Image pull failed**:

   ```bash
   # Pull image manually
   podman pull IMAGE_NAME:TAG

   # Check registry connectivity
   podman login nas.discus-moth.ts.net:5001
   ```

4. **Quadlet file syntax error**:

   ```bash
   # Regenerate systemd units
   systemctl --user daemon-reload

   # Check generated service file
   cat ~/.config/containers/systemd/CONTAINER_NAME.container
   systemctl --user cat CONTAINER_NAME
   ```

### 3. Container Keeps Restarting

**Symptoms**:

- Container status shows "Restarting"
- Service unavailable intermittently
- High CPU usage

**Diagnosis**:

```bash
# Check container status
podman ps -a | grep CONTAINER_NAME

# View logs for crash cause
podman logs CONTAINER_NAME --tail 200

# Check restart count
podman inspect CONTAINER_NAME | grep RestartCount

# Monitor in real-time
podman stats CONTAINER_NAME
```

**Solutions**:

1. **Application error**:
   - Check logs for specific error messages
   - Fix configuration issues
   - Ensure all dependencies are met

2. **Resource limits (OOM)**:

   ```bash
   # Check if container is OOM killed
   podman inspect CONTAINER_NAME | grep OOMKilled

   # Increase memory limit in .container file
   # PodmanArgs=--memory 2g
   systemctl --user daemon-reload
   systemctl --user restart CONTAINER_NAME
   ```

3. **Health check failing**:

   ```bash
   # Check health check status
   podman healthcheck run CONTAINER_NAME

   # View health check logs
   podman inspect CONTAINER_NAME | grep -A 10 Health
   ```

### 4. Quadlet/Systemd Issues

**Symptoms**:

- `systemctl --user` commands fail
- Services don't start on boot
- "Unit not found" errors

**Diagnosis**:

```bash
# Check if Quadlet files exist
ls ~/.config/containers/systemd/

# Reload systemd to regenerate units
systemctl --user daemon-reload

# List generated services
systemctl --user list-units --type=service | grep -E "sonarr|radarr|podman"

# Check for Quadlet errors
journalctl --user -u systemd-*.service | grep -i quadlet
```

**Solutions**:

1. **Service not found**:

   ```bash
   # Ensure .container file exists
   ls ~/.config/containers/systemd/CONTAINER_NAME.container

   # Reload to generate service
   systemctl --user daemon-reload

   # Enable and start
   systemctl --user enable --now CONTAINER_NAME
   ```

2. **Services don't start on boot**:

   ```bash
   # Enable lingering
   sudo loginctl enable-linger ansible

   # Enable service
   systemctl --user enable CONTAINER_NAME
   ```

3. **Check Quadlet file syntax**:

   ```bash
   # Validate by viewing generated unit
   systemctl --user cat CONTAINER_NAME

   # If empty or error, check .container file syntax
   ```

### 5. Volume Mount Issues

**Symptoms**:

- Data not persisting
- "Permission denied" in containers
- Wrong files showing in container

**Diagnosis**:

```bash
# Check volume mounts
podman inspect CONTAINER_NAME | grep -A 20 Mounts

# Check if bind mount exists on host
ls -la /path/to/mount

# Check permissions
ls -ld /path/to/mount

# Test from inside container
podman exec CONTAINER_NAME ls -la /mount/path
```

**Solutions**:

1. **Mount path doesn't exist**:

   ```bash
   # Create directory on host
   sudo mkdir -p /path/to/mount

   # Set correct ownership
   sudo chown -R ansible:ansible /path/to/mount
   ```

2. **NFS permission denied**:

   ```bash
   # NFS uses nfsuser (UID 3000)
   # Ensure container runs with matching PUID/PGID
   # In .container file:
   # Environment=PUID=3000
   # Environment=PGID=3000
   ```

3. **Rootless UID mapping issues**:

   ```bash
   # Check subuid/subgid
   cat /etc/subuid
   cat /etc/subgid

   # Use :U flag for auto-chown (local volumes only, not NFS)
   # Volume=/opt/data:/data:U
   ```

### 6. Network Issues

**Symptoms**:

- Containers can't reach each other
- Container can't reach internet
- DNS resolution fails

**Diagnosis**:

```bash
# List networks
podman network ls

# Inspect network
podman network inspect NETWORK_NAME

# Test connectivity between containers
podman exec sonarr ping prowlarr

# Test internet from container
podman exec sonarr ping -c 3 8.8.8.8
podman exec sonarr ping -c 3 google.com
```

**Solutions**:

1. **Containers on different networks**:

   ```bash
   # Check which network containers are on
   podman inspect CONTAINER_NAME | grep NetworkMode

   # Use same network in .container file
   # Network=media-services-net
   ```

2. **DNS not working**:

   ```bash
   # Add DNS to .container file
   # PodmanArgs=--dns 192.168.0.15
   ```

3. **Use container names for inter-container communication**:
   - Correct: `http://prowlarr:9696`
   - Wrong: `http://localhost:9696`

### 7. High Disk Usage

**Symptoms**:

- Disk space filling up
- "No space left on device" errors
- Podman using too much space

**Diagnosis**:

```bash
# Check Podman disk usage
podman system df

# Check detailed usage
podman system df -v

# Find large containers
podman ps -as

# Find large images
podman images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h
```

**Solutions**:

1. **Clean up unused resources**:

   ```bash
   # Remove stopped containers
   podman container prune

   # Remove unused images
   podman image prune

   # Remove unused volumes
   podman volume prune

   # Remove everything unused (CAREFUL!)
   podman system prune -a --volumes
   ```

2. **Large log files**:

   ```bash
   # Check container log sizes
   du -sh ~/.local/share/containers/storage/overlay-containers/*/userdata/

   # Logs are managed by journald for Quadlet services
   journalctl --user --vacuum-size=100M
   ```

## Advanced Troubleshooting

### Container Shell Access

```bash
# Access running container shell
podman exec -it CONTAINER_NAME /bin/bash

# Or if bash not available
podman exec -it CONTAINER_NAME /bin/sh

# Run commands as root in container
podman exec -u root -it CONTAINER_NAME /bin/bash
```

### Debug Container Networking

```bash
# Enter container
podman exec -it CONTAINER_NAME /bin/bash

# Inside container, test connectivity
ping sonarr
ping 8.8.8.8
nslookup google.com

# Check DNS config
cat /etc/resolv.conf
```

### View Podman Events

```bash
# Monitor Podman events in real-time
podman events

# Filter events for specific container
podman events --filter container=sonarr
```

### Rebuild Container After Changes

```bash
# Stop and remove container
systemctl --user stop CONTAINER_NAME
podman rm CONTAINER_NAME

# Pull latest image
podman pull IMAGE_NAME:TAG

# Reload and restart
systemctl --user daemon-reload
systemctl --user start CONTAINER_NAME
```

### Reset Container Completely

```bash
# Stop service
systemctl --user stop CONTAINER_NAME

# Remove container and its volumes
podman rm -v CONTAINER_NAME

# Remove image
podman rmi IMAGE_NAME:TAG

# Recreate
systemctl --user daemon-reload
systemctl --user start CONTAINER_NAME
```

## Getting Help

If issues persist:

1. **Collect diagnostic info**:

   ```bash
   podman version > /tmp/podman-debug.txt
   podman info >> /tmp/podman-debug.txt
   podman ps -a >> /tmp/podman-debug.txt
   podman system df >> /tmp/podman-debug.txt
   journalctl --user -n 200 >> /tmp/podman-debug.txt
   ```

2. **Podman Resources**:
   - Official docs: <https://docs.podman.io/>
   - GitHub issues: <https://github.com/containers/podman/issues>
   - Quadlet docs: <https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html>

## See Also

- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Download Clients Troubleshooting](download-clients.md)
- [Prowlarr Troubleshooting](prowlarr.md)
- [Networking Troubleshooting](networking.md)
- [Common Issues](common-issues.md)
