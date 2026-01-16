# Common Issues

Cross-service problems and general troubleshooting guidance.

> **IMPORTANT**: Most services run as **rootless Podman containers with Quadlet**. Use `systemctl --user` and `podman`
> commands, NOT `docker` commands. Native services (Jellyfin, Satisfactory) use regular `systemctl`.

## Quick Diagnostic Commands

```bash
# System health
free -h
df -h
top
sudo systemctl --failed
systemctl --user --failed

# Network
ping 8.8.8.8
tailscale status
sudo ufw status

# Podman containers (rootless)
podman ps
podman stats

# NFS
df -h /mnt/data
mount | grep /mnt/data
```

## Common Cross-Service Issues

### 1. Everything Stopped Working After Reboot

**Symptoms**:

- Services were working, now nothing accessible
- Podman containers not running
- NFS mounts missing

**Diagnosis**:

```bash
# Check what's running
systemctl --user list-units --type=service --state=running
podman ps
sudo systemctl --failed
df -h /mnt/data

# Check boot logs
sudo journalctl -b | grep -i error
```

**Solutions**:

1. **NFS not mounted**:

   ```bash
   sudo mount -a
   # Check /etc/fstab has _netdev option
   ```

2. **Quadlet services not started**:

   ```bash
   # Enable lingering for user services to start at boot
   loginctl enable-linger $(whoami)

   # Start services
   systemctl --user start sonarr radarr prowlarr
   ```

3. **Services in wrong order**:
   - NFS must mount before Podman containers start
   - Check systemd service dependencies in Quadlet .container files

### 2. Permission Denied Errors Everywhere

**Symptoms**:

- Multiple services can't write files
- "Permission denied" in logs
- Files created with wrong ownership

**Diagnosis**:

```bash
# Check NFS mount permissions
ls -la /mnt/data

# Check ownership of key directories
ls -la /opt/media-stack
ls -la /opt/download-clients

# Verify UID/GID
id nfsuser
```

**Solutions**:

1. **Fix NFS permissions** (most common):

   ```bash
   # On NAS
   sudo chown -R 3000:3000 /mnt/storage/data
   sudo chmod -R 775 /mnt/storage/data

   # On clients
   sudo mount -o remount /mnt/data
   ```

2. **Verify nfsuser exists** on all VMs:

   ```bash
   id nfsuser
   # Should show uid=3000 gid=3000

   # Create if missing
   sudo groupadd -g 3000 nfsusers
   sudo useradd -u 3000 -g 3000 -s /bin/false nfsuser
   ```

3. **Check container PUID/PGID**:

   ```bash
   # Should be 3000:3000 in Quadlet .container files
   podman exec sonarr env | grep -E "PUID|PGID"
   ```

### 3. Can't Access Anything Remotely

**Symptoms**:

- All services work locally but not remotely
- Tailscale hostnames not resolving
- Can't SSH from outside

**Diagnosis**:

```bash
# Check Tailscale status
tailscale status

# Check if services are listening
sudo netstat -tulpn | grep -E "8989|7878|8080"

# Check firewall
sudo ufw status
```

**Solutions**:

1. **Tailscale not connected**:

   ```bash
   sudo systemctl status tailscaled
   sudo tailscale up
   ```

2. **Firewall blocking** (after Phase 4):
   - SSH via Tailscale hostnames or local network IPs
   - Services accessible from local network + Tailscale
   - Check UFW rules allow Tailscale network (100.64.0.0/10)

3. **Use correct hostnames**:
   - Sonarr: `http://media-services.discus-moth.ts.net:8989`
   - Radarr: `http://media-services.discus-moth.ts.net:7878`
   - qBittorrent: `http://download-clients.discus-moth.ts.net:8080`

### 4. Services Running But Not Communicating

**Symptoms**:

- Sonarr can't reach Prowlarr
- Prowlarr can't add indexers to Sonarr/Radarr
- Download clients not connecting

**Diagnosis**:

```bash
# Check all services are up
systemctl --user status sonarr radarr prowlarr
podman ps | grep -E "sonarr|radarr|prowlarr|qbittorrent|sabnzbd"

# Test connectivity (from media-services VM)
curl http://localhost:8989  # Sonarr
curl http://localhost:9696  # Prowlarr
curl http://download-clients.discus-moth.ts.net:8080  # qBittorrent
```

**Solutions**:

1. **Use correct hostnames**:
   - **Within same VM**: Use `localhost` (services on media-services VM can reach each other)
   - **To download clients**: Use Tailscale or IP (`download-clients.discus-moth.ts.net:8080`)
   - **From browser**: Use Tailscale hostnames

2. **Common hostname patterns**:

   ```text
   # Within media-services VM (all services use host networking)
   Sonarr → Prowlarr: http://localhost:9696
   Sonarr → Radarr: http://localhost:7878
   Prowlarr → Sonarr: http://localhost:8989

   # From media-services to download-clients (different VM)
   Sonarr → qBittorrent: http://download-clients.discus-moth.ts.net:8080
   Prowlarr → SABnzbd: http://download-clients.discus-moth.ts.net:8081

   # From browser
   Use Tailscale hostnames: http://media-services.discus-moth.ts.net:8989
   ```

### 5. High CPU or RAM Usage

**Symptoms**:

- System slow or unresponsive
- Services timing out
- VM performance degraded

**Diagnosis**:

```bash
# Check overall usage
top
htop  # if installed

# Check per-VM CPU assignment
# On Proxmox
qm config VMID | grep cores

# Check Podman container resource usage
podman stats

# Check for runaway processes
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
```

**Solutions**:

1. **Jellyfin transcoding**:
   - CPU intensive during 4K transcodes
   - Normal behavior, has high priority
   - Consider limiting concurrent transcodes

2. **Container runaway**:

   ```bash
   # Check which container
   podman stats

   # Restart problematic service
   systemctl --user restart CONTAINER_NAME
   ```

3. **Memory leak**:

   ```bash
   # Check memory usage over time
   free -h

   # Restart services
   systemctl --user restart sonarr radarr prowlarr
   ```

### 6. Disk Space Full

**Symptoms**:

- "No space left on device"
- Services failing to write
- Downloads failing

**Diagnosis**:

```bash
# Check all mounts
df -h

# Check what's using space
du -sh /mnt/data/*
du -sh ~/.local/share/containers/*

# Check for large files
find /mnt/data -type f -size +10G -exec ls -lh {} \;
```

**Solutions**:

1. **Media directory full**:

   ```bash
   # Check media storage
   du -sh /mnt/data/media/*
   du -sh /mnt/data/torrents/*

   # Delete unwanted media in Sonarr/Radarr
   # Or increase NAS storage
   ```

2. **Podman using too much space**:

   ```bash
   # Check Podman usage
   podman system df

   # Clean up
   podman system prune -a
   ```

3. **Logs too large**:

   ```bash
   # Check log sizes
   sudo du -sh /var/log/*
   du -sh ~/.local/share/containers/storage/

   # Clear old logs
   sudo journalctl --vacuum-time=7d
   journalctl --user --vacuum-time=7d
   ```

### 7. Playbook Execution Failures

**Symptoms**:

- Ansible playbook fails
- Tasks timing out
- Connection errors

**Diagnosis**:

```bash
# Test Ansible connectivity
ansible all -m ping -i inventory.ini

# Check VM is accessible
ping media-services.discus-moth.ts.net
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check secrets file
sops -d group_vars/all.sops.yaml
```

**Solutions**:

1. **Connection timeout**:
   - Verify VM is running
   - Check SSH keys are correct
   - Ensure Tailscale is connected

2. **Task idempotency**:
   - Most playbooks are idempotent (safe to re-run)
   - Re-run failed playbook

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/core/PLAYBOOK.yml
   ```

3. **Secrets file issues**:
   - Verify age key is accessible
   - Check secrets file has required keys

## After Major Changes

### After Updating Quadlet Container Files

```bash
# Reload systemd to pick up changes
systemctl --user daemon-reload

# Pull new images if needed
podman pull <image>

# Restart services
systemctl --user restart sonarr radarr prowlarr

# Check logs
journalctl --user -u sonarr -f
```

### After Changing Network Config

```bash
# Restart networking
sudo netplan apply

# Restart Tailscale
sudo systemctl restart tailscaled
```

### After Firewall Changes

```bash
# Reload firewall
sudo ufw reload

# Test access
ssh -i ~/.ssh/ansible_homelab ansible@HOSTNAME.discus-moth.ts.net

# Check rules
sudo ufw status numbered
```

## General Troubleshooting Approach

1. **Check service status**:

   ```bash
   # For Quadlet services (most containers)
   systemctl --user status SERVICE_NAME
   podman ps

   # For native services (Jellyfin, Satisfactory)
   sudo systemctl status SERVICE_NAME
   ```

2. **View logs**:

   ```bash
   # For Quadlet services
   journalctl --user -u SERVICE_NAME -f
   podman logs CONTAINER_NAME -f

   # For native services
   sudo journalctl -u SERVICE_NAME -f
   ```

3. **Test connectivity**:

   ```bash
   ping HOST
   curl http://HOST:PORT
   ```

4. **Check resources**:

   ```bash
   free -h
   df -h
   top
   ```

5. **Verify configuration**:
   - Check config files for typos
   - Verify environment variables
   - Ensure paths are correct

## When All Else Fails

### Restart Everything

```bash
# Stop all Quadlet services
systemctl --user stop sonarr radarr prowlarr jellyseerr
systemctl --user stop qbittorrent sabnzbd gluetun

# Restart networking
sudo systemctl restart systemd-networkd
sudo systemctl restart tailscaled

# Remount NFS
sudo umount /mnt/data
sudo mount -a

# Start services
systemctl --user start gluetun qbittorrent sabnzbd
systemctl --user start sonarr radarr prowlarr jellyseerr
```

### Re-run Relevant Playbook

```bash
# Most playbooks are idempotent
./bin/runtime/ansible-run.sh playbooks/core/RELEVANT_PLAYBOOK.yml
```

### Check Documentation

Refer to service-specific troubleshooting:

- [Jellyfin](jellyfin.md)
- [Sonarr/Radarr](sonarr-radarr.md)
- [Prowlarr](prowlarr.md)
- [Download Clients](download-clients.md)
- [NAS/NFS](nas-nfs.md)
- [Networking](networking.md)
- [Podman](podman.md)

## Getting Help

1. **Collect system info**:

   ```bash
   # Create debug bundle
   mkdir -p /tmp/debug
   podman ps -a > /tmp/debug/podman-ps.txt
   df -h > /tmp/debug/disk-usage.txt
   free -h > /tmp/debug/memory.txt
   sudo ufw status > /tmp/debug/firewall.txt
   tailscale status > /tmp/debug/tailscale.txt

   # Collect all logs
   journalctl --user -n 500 > /tmp/debug/user-services.txt
   sudo journalctl -n 500 > /tmp/debug/system-logs.txt
   ```

2. **Document the issue**:
   - What were you trying to do?
   - What happened instead?
   - What have you tried?
   - Include relevant logs and error messages

## See Also

- [Architecture Overview](../architecture.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Playbooks Reference](../reference/playbooks.md)
