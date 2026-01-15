# Troubleshooting Guide

Central troubleshooting hub for diagnosing and resolving issues across the Jellybuntu infrastructure.

## Quick Navigation

### By Service

**Media Streaming**:

- [Jellyfin Issues](../troubleshooting/jellyfin.md) - Transcoding, playback, library problems

**Media Management**:

- [Sonarr/Radarr Issues](../troubleshooting/sonarr-radarr.md) - TV/Movie automation, API, metadata
- [Prowlarr Issues](../troubleshooting/prowlarr.md) - Indexer connectivity, sync problems

**Downloads**:

- [Download Client Issues](../troubleshooting/download-clients.md) - qBittorrent, SABnzbd problems

**Infrastructure**:

- [NAS and NFS Issues](../troubleshooting/nas-nfs.md) - Storage, mounts, Btrfs, snapshots
- [Networking Issues](../troubleshooting/networking.md) - Tailscale, firewall, SSH, connectivity
- [Podman Issues](../troubleshooting/podman.md) - Container problems, Quadlet/systemd issues

**General**:

- [Common Issues](../troubleshooting/common-issues.md) - Cross-service problems

### By Symptom

**Can't Access Service**:

1. Check service status → [Podman Issues](../troubleshooting/podman.md)
2. Check network/firewall → [Networking Issues](../troubleshooting/networking.md)
3. Check specific service guide

**Poor Performance**:

1. Check resource usage → [Common Issues](../troubleshooting/common-issues.md)
2. Check Jellyfin transcoding → [Jellyfin Issues](../troubleshooting/jellyfin.md)
3. Check disk I/O → [NAS and NFS Issues](../troubleshooting/nas-nfs.md)

**Services Not Working**:

1. Check Podman containers → [Podman Issues](../troubleshooting/podman.md)
2. Check NFS mounts → [NAS and NFS Issues](../troubleshooting/nas-nfs.md)
3. Check service-specific guide

**Download Problems**:

1. Check download clients → [Download Client Issues](../troubleshooting/download-clients.md)
2. Check Prowlarr indexers → [Prowlarr Issues](../troubleshooting/prowlarr.md)
3. Check Sonarr/Radarr → [Sonarr/Radarr Issues](../troubleshooting/sonarr-radarr.md)

## General Troubleshooting Methodology

### Step 1: Identify the Problem

**Ask**:

- What is not working?
- When did it stop working?
- What changed recently?
- Is it affecting one service or multiple?

**Check**:

```bash
# Service accessibility
curl -I http://<service>.discus-moth.ts.net:<port>

# VM status
ssh root@jellybuntu.discus-moth.ts.net "qm list"

# Docker containers
ssh ansible@<vm>.discus-moth.ts.net "docker compose ps"

# System resources
ssh ansible@<vm>.discus-moth.ts.net "htop"
```

### Step 2: Gather Information

**Logs**:

```bash
# Docker container logs
docker compose logs <service>

# Docker container logs (last 100 lines)
docker compose logs --tail=100 <service>

# Follow logs in real-time
docker compose logs -f <service>

# System logs (systemd)
sudo journalctl -u <service> -n 100

# Jellyfin logs (native install)
sudo journalctl -u jellyfin -n 100
sudo tail -f /var/log/jellyfin/log_*.txt
```

**System State**:

```bash
# Disk space
df -h

# Memory usage
free -h

# CPU usage
top -bn1 | head -20

# Network connectivity
ping -c 4 8.8.8.8
ping -c 4 nas.discus-moth.ts.net

# NFS mounts
mount | grep nfs
df -h | grep nfs
```

**Service Status**:

```bash
# Docker services
docker compose ps

# Systemd services
systemctl status <service>

# Tailscale
tailscale status

# Firewall
sudo ufw status
```

### Step 3: Check Common Causes

**Network Issues**:

- Is Tailscale running?
- Are firewall rules correct?
- Can you ping the service?
- Is DNS resolving correctly?

**Resource Issues**:

- Is disk full?
- Is RAM exhausted?
- Is CPU maxed out?
- Are there I/O bottlenecks?

**Configuration Issues**:

- Did configuration change recently?
- Are credentials correct?
- Are paths correct?
- Are permissions correct?

**Dependency Issues**:

- Is NFS mounted?
- Is the database accessible?
- Are required services running?
- Are API keys valid?

### Step 4: Test and Isolate

**Test Components Individually**:

```bash
# Test network
curl -I http://localhost:<port>  # From VM itself
curl -I http://<vm-ip>:<port>    # From another VM
curl -I http://<vm>.discus-moth.ts.net:<port>  # Via Tailscale

# Test NFS
ls -la /mnt/data  # Should show files
touch /mnt/data/test.txt  # Should succeed
rm /mnt/data/test.txt

# Test Docker
docker ps  # Should show running containers
docker compose config  # Should show no errors
```

**Isolate the Problem**:

- Does it work locally but not remotely? → Network issue
- Does it work on one VM but not another? → VM-specific issue
- Does it work for some users but not others? → Permissions/auth issue
- Did it start after an update? → Update regression

### Step 5: Fix and Verify

**Apply Fix**:

- Restart service
- Remount NFS
- Fix configuration
- Update firewall rules

**Verify Resolution**:

```bash
# Check service is accessible
curl -I http://<service>.discus-moth.ts.net:<port>

# Check logs for errors
docker compose logs <service> --tail=50

# Test functionality
# - Access web UI
# - Trigger an action (download, scan, etc.)
# - Verify expected behavior
```

**Document**:

- What was the problem?
- What fixed it?
- How to prevent it in the future?

## Common First Steps

### Service Not Accessible

**Check from workstation**:

```bash
# Test Tailscale connectivity
ping <vm>.discus-moth.ts.net

# Test service port
curl -I http://<vm>.discus-moth.ts.net:<port>
```

**Check on VM**:

```bash
# SSH to VM
ssh ansible@<vm>.discus-moth.ts.net

# Check service is running
docker compose ps
# or
sudo systemctl status <service>

# Check local access
curl -I http://localhost:<port>

# Check firewall
sudo ufw status | grep <port>
```

### Container Not Running

```bash
# Check container status
docker compose ps

# View logs
docker compose logs <service>

# Restart container
docker compose restart <service>

# Recreate container (if needed)
docker compose up -d <service>

# Check configuration
docker compose config
```

### High Resource Usage

```bash
# Check what's using resources
htop

# Check disk usage
df -h
du -sh /* | sort -h

# Check Docker disk usage
docker system df

# Check for runaway processes
ps aux --sort=-%cpu | head -10
ps aux --sort=-%mem | head -10
```

### Network Connectivity Issues

```bash
# Check Tailscale
tailscale status
tailscale ping <vm>.discus-moth.ts.net

# Check local network
ping 192.168.0.1  # Gateway
ping 192.168.0.15  # NAS
ping 8.8.8.8  # Internet

# Check firewall
sudo ufw status verbose

# Check SSH access
ssh ansible@<vm>.discus-moth.ts.net
```

## Diagnostic Commands Reference

### System Information

```bash
# System overview
uname -a
lsb_release -a

# Uptime
uptime

# Disk info
lsblk
df -h

# Memory info
free -h

# CPU info
lscpu
cat /proc/cpuinfo

# Network interfaces
ip addr
ip route
```

### Service Diagnostics

**Docker**:

```bash
docker compose ps              # Container status
docker compose logs <service>  # Container logs
docker compose config          # Validate config
docker compose images          # List images
docker stats                   # Resource usage
docker system df              # Disk usage
```

**Systemd**:

```bash
systemctl status <service>     # Service status
journalctl -u <service>        # Service logs
systemctl list-units --failed  # Failed units
```

**Network**:

```bash
ss -tuln                       # Listening ports
netstat -tuln | grep LISTEN   # Alternative
iptables -L -n -v             # Firewall rules
ufw status verbose            # UFW status
```

### Log Locations

**Docker Containers**:

- Command: `docker compose logs <service>`
- Location: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`

**Jellyfin** (native):

- System: `journalctl -u jellyfin`
- Application: `/var/log/jellyfin/`

**System Logs**:

- Syslog: `/var/log/syslog`
- Auth: `/var/log/auth.log`
- Kernel: `dmesg` or `journalctl -k`

**Apt/Updates**:

- History: `/var/log/apt/history.log`
- Unattended: `/var/log/unattended-upgrades/unattended-upgrades.log`

**Proxmox** (on host):

- System: `journalctl -xe`
- VM logs: `/var/log/pve/`

## Problem Categories

### Infrastructure Problems

**Proxmox Host Issues**:

- SSH to Proxmox host
- Check system resources: `htop`, `df -h`
- Check VM status: `qm list`
- See: [Power Management](power-management.md)

**VM Won't Start**:

- Check VM config: `qm config <vmid>`
- Check host resources
- Check VM disk: `pvesm status`
- See: [Power Management](power-management.md)

**Network Problems**:

- Check Tailscale: `tailscale status`
- Check firewall: `sudo ufw status`
- Check connectivity: `ping`, `curl`
- See: [Networking Issues](../troubleshooting/networking.md)

**Storage Problems**:

- Check NFS: `df -h | grep nfs`
- Check Btrfs: `btrfs filesystem df /mnt/storage`
- Check disk space: `df -h`
- See: [NAS and NFS Issues](../troubleshooting/nas-nfs.md)

### Application Problems

**Media Streaming**:

- Jellyfin transcoding issues
- Playback problems
- Library not updating
- See: [Jellyfin Issues](../troubleshooting/jellyfin.md)

**Media Management**:

- Sonarr/Radarr not finding releases
- API connection failures
- Metadata not updating
- See: [Sonarr/Radarr Issues](../troubleshooting/sonarr-radarr.md)

**Download Issues**:

- qBittorrent not downloading
- SABnzbd errors
- Incomplete downloads
- See: [Download Client Issues](../troubleshooting/download-clients.md)

**Indexer Issues**:

- Prowlarr sync failures
- Indexer connectivity
- Rate limiting
- See: [Prowlarr Issues](../troubleshooting/prowlarr.md)

## Emergency Recovery

### Complete System Failure

**Proxmox Host Down**:

1. Check physical host power/network
2. Access via local console if possible
3. Reboot host if necessary
4. VMs should auto-start (if configured)
5. See: [Power Management](power-management.md)

**All VMs Down**:

1. Check Proxmox host is running
2. Check Proxmox resources: `htop`, `df -h`
3. Start VMs in order: NAS first, then clients
4. See: [Power Management](power-management.md) - Manual Power Management

**NFS Completely Unavailable**:

1. Check NAS VM is running: `qm status 300`
2. Check NFS service: `ssh ansible@nas.discus-moth.ts.net "systemctl status nfs-server"`
3. Restart NFS if needed
4. Remount on clients: `ssh ansible@jellyfin.discus-moth.ts.net "sudo mount -a"`
5. See: [NAS and NFS Issues](../troubleshooting/nas-nfs.md)

### Data Recovery

**VM Snapshots**:

```bash
# List snapshots
ssh root@jellybuntu.discus-moth.ts.net "qm listsnapshot <vmid>"

# Rollback to snapshot
ssh root@jellybuntu.discus-moth.ts.net "qm rollback <vmid> <snapshot-name>"
```

**Btrfs Snapshots**:

```bash
# List snapshots
ssh ansible@nas.discus-moth.ts.net "sudo btrfs subvolume list /mnt/storage"

# Restore from snapshot (example)
ssh ansible@nas.discus-moth.ts.net "sudo btrfs subvolume snapshot /mnt/storage/.snapshots/backup /mnt/storage/data"
```

**Docker Volume Backup**:

```bash
# Backup configuration
ssh ansible@media-services.discus-moth.ts.net
cd ~/docker-compose
tar -czf ~/config-backup-$(date +%Y%m%d).tar.gz config/
```

## Getting Help

### Information to Gather

Before asking for help, gather:

1. **What's wrong**: Specific error or symptom
2. **When it started**: Timeline of issue
3. **What changed**: Recent updates, config changes
4. **Error messages**: Exact error text or screenshots
5. **Logs**: Relevant log excerpts
6. **Environment**: Which VMs, services affected

### Useful Commands for Diagnostics

**Full System Report**:

```bash
#!/bin/bash
# Save as ~/get-diagnostics.sh

echo "=== System Info ==="
uname -a
uptime

echo -e "\n=== Disk Space ==="
df -h

echo -e "\n=== Memory ==="
free -h

echo -e "\n=== Docker Containers ==="
docker compose ps

echo -e "\n=== NFS Mounts ==="
mount | grep nfs

echo -e "\n=== Firewall Status ==="
sudo ufw status

echo -e "\n=== Tailscale Status ==="
tailscale status

echo -e "\n=== Recent Logs ==="
sudo journalctl -n 50 --no-pager
```

**Usage**:

```bash
ssh ansible@<vm>.discus-moth.ts.net
chmod +x ~/get-diagnostics.sh
./get-diagnostics.sh > diagnostics-$(hostname)-$(date +%Y%m%d).txt
```

### Community Resources

**Official Documentation**:

- [Jellyfin Docs](https://jellyfin.org/docs/)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Proxmox Documentation](https://pve.proxmox.com/wiki/Main_Page)

**Community Forums**:

- [Jellyfin Forum](https://forum.jellyfin.org/)
- [Servarr Discord](https://discord.gg/M6BvZn5) - Sonarr/Radarr/Prowlarr
- [Proxmox Forum](https://forum.proxmox.com/)
- [r/selfhosted](https://reddit.com/r/selfhosted)

## Preventive Measures

### Regular Maintenance

**Weekly**:

- Check service status
- Review logs for errors
- Monitor disk space
- Verify backups

**Monthly**:

- Update services (see [Updates](updates.md))
- Check resource usage trends
- Review security logs
- Test restore procedures

### Monitoring Setup

**Basic Monitoring**:

```bash
# Create simple monitoring script
cat > ~/check-services.sh << 'EOF'
#!/bin/bash
# Check all critical services

SERVICES=(
  "media-services.discus-moth.ts.net:8989:Sonarr"
  "media-services.discus-moth.ts.net:7878:Radarr"
  "download-clients.discus-moth.ts.net:8080:qBittorrent"
  "jellyfin.discus-moth.ts.net:8096:Jellyfin"
)

for service in "${SERVICES[@]}"; do
  IFS=':' read -r host port name <<< "$service"
  if curl -s -o /dev/null -w "%{http_code}" http://$host:$port | grep -q "200\|302\|401"; then
    echo "✓ $name is UP"
  else
    echo "✗ $name is DOWN"
  fi
done
EOF

chmod +x ~/check-services.sh
```

**Run regularly**:

```bash
# Add to crontab (check every hour)
crontab -e
# Add line:
0 * * * * ~/check-services.sh >> ~/service-status.log
```

### Documentation

**Document Changes**:

- When you modify configuration
- When you update services
- When you troubleshoot issues
- Solutions that worked

**Keep Track Of**:

- Service versions
- Configuration locations
- API keys and credentials (in vault)
- Known issues and workarounds

## Summary

**Troubleshooting Process**:

1. Identify the problem and gather information
2. Check logs and system state
3. Test and isolate the issue
4. Apply fix and verify resolution
5. Document the solution

**Quick Checks**:

```bash
# Service status
docker compose ps
systemctl status <service>

# Logs
docker compose logs <service>
journalctl -u <service>

# Resources
df -h
free -h
htop

# Network
tailscale status
sudo ufw status
ping <host>
```

**Service-Specific Guides**:

- [Jellyfin](../troubleshooting/jellyfin.md)
- [Sonarr/Radarr](../troubleshooting/sonarr-radarr.md)
- [Prowlarr](../troubleshooting/prowlarr.md)
- [Download Clients](../troubleshooting/download-clients.md)
- [NAS/NFS](../troubleshooting/nas-nfs.md)
- [Networking](../troubleshooting/networking.md)
- [Podman](../troubleshooting/podman.md)
- [Common Issues](../troubleshooting/common-issues.md)

**Maintenance**:

- [Updates Guide](updates.md)
- [Power Management](power-management.md)

Most issues can be resolved by checking logs, verifying service status, and ensuring dependencies (NFS, network, Docker)
are functioning!
