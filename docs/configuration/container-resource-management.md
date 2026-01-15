# Container Resource Management

Guide to managing Podman container resources, monitoring performance, and troubleshooting resource contention in the
Jellybuntu infrastructure.

## Overview

Podman containers (managed via Quadlet systemd units) share host resources (CPU, memory, disk I/O, network). Without
limits, one container can monopolize resources and impact others. This guide covers setting appropriate limits and
monitoring.

## Current Resource Allocation

### VM Resources

| VM | vCPU | RAM | Services | Notes |
|----|------|-----|----------|-------|
| media-services | 2 | 6GB | Sonarr, Radarr, Prowlarr, etc. | Shared workload |
| download-clients | 2 | 6GB | qBittorrent, SABnzbd, Gluetun | VPN overhead |
| jellyfin | 4 | 8GB | Jellyfin | Transc coding-optimized |
| nas | 2 | 6GB | NFS server | I/O focused |

### Container Resource Defaults

By default, containers have **no limits** and can use all available VM resources.

## Monitoring Container Resources

### Real-Time Stats

> **Note**: Rootless Podman requires `XDG_RUNTIME_DIR` to locate the user's runtime directory (where the Podman socket
> lives). When SSHing in, this variable may not be set. The export below ensures commands work correctly.

```bash
# All containers on VM (set XDG_RUNTIME_DIR for SSH sessions)
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats

# Specific containers
podman stats sonarr radarr prowlarr

# One-time snapshot
podman stats --no-stream

# Format output
podman stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Expected Resource Usage

**Typical Resource Consumption**:

| Service | CPU (idle) | CPU (active) | Memory | Notes |
|---------|------------|--------------|--------|-------|
| Sonarr | <5% | 20-40% | 150-300MB | Peaks during scans |
| Radarr | <5% | 20-40% | 150-300MB | Peaks during scans |
| Prowlarr | <2% | 10-20% | 50-100MB | Lightweight |
| Jellyseerr | <2% | 5-10% | 100-150MB | Low usage |
| qBittorrent | 5-15% | 30-60% | 200-400MB | Active downloads |
| SABnzbd | <5% | 40-80% | 150-300MB | Unpack heavy |
| Jellyfin | <5% | 200-400% | 500MB-2GB | Transcoding multi-core |
| Gluetun | <2% | 5-10% | 50-100MB | VPN overhead |
| FlareSolverr | <5% | 50-100% | 500MB-1GB | Chrome browser |

## Setting Resource Limits

### Quadlet Method (Recommended)

Add limits to `.container` files in `~/.config/containers/systemd/`:

```ini
[Container]
ContainerName=sonarr
Image=nas.discus-moth.ts.net:5001/linuxserver/sonarr:latest
# ... existing config ...

# Resource limits via PodmanArgs
PodmanArgs=--memory 512m
PodmanArgs=--memory-reservation 256m
PodmanArgs=--cpus 1.0
```

### Apply Limits to Media Services

Edit `~/.config/containers/systemd/sonarr.container`:

```ini
[Container]
ContainerName=sonarr
# ... existing config ...
PodmanArgs=--memory 512m
PodmanArgs=--memory-reservation 256m
```

Reload and restart services:

```bash
systemctl --user daemon-reload
systemctl --user restart sonarr
```

### Runtime Limits (Quick Method)

Set limits on running container:

```bash
# Update memory limit (requires container recreation with Quadlet)
# Edit the .container file and restart:
systemctl --user restart sonarr

# View current limits
podman inspect sonarr | grep -A10 "HostConfig"
```

## Recommended Resource Limits

### Media Services VM

```yaml
sonarr:
  limits: {cpus: '1.0', memory: 512M}
radarr:
  limits: {cpus: '1.0', memory: 512M}
prowlarr:
  limits: {cpus: '0.5', memory: 256M}
bazarr:
  limits: {cpus: '0.5', memory: 384M}
jellyseerr:
  limits: {cpus: '0.5', memory: 256M}
huntarr:
  limits: {cpus: '0.25', memory: 128M}
homarr:
  limits: {cpus: '0.25', memory: 256M}
flaresolverr:
  limits: {cpus: '1.0', memory: 1536M}
recyclarr:
  limits: {cpus: '0.5', memory: 256M}
```

**Total**: ~4GB reserved (leaves 4GB VM overhead)

### Download Clients VM

**Currently deployed** (memory only, no CPU limits):

```yaml
gluetun:
  limits: {memory: 512M, memory_reservation: 256M}
qbittorrent:
  limits: {memory: 2GB, memory_reservation: 1GB}
sabnzbd:
  limits: {memory: 2GB, memory_reservation: 1GB}
unpackerr:
  limits: {memory: 512M, memory_reservation: 256M}
cadvisor:
  limits: {memory: 256M, memory_reservation: 128M}
```

**Total**: ~5.28GB reserved (~91% of 6GB VM RAM)

> **Note**: SABnzbd requires 2GB for par2 verification/repair operations. Previous 1GB limit caused
> repeated OOM kills during intensive downloads.

**Optional CPU limits** (if CPU contention becomes an issue):

```yaml
gluetun:     {cpus: '0.5'}
qbittorrent: {cpus: '1.5'}
sabnzbd:     {cpus: '1.5'}
unpackerr:   {cpus: '0.5'}
```

### Jellyfin VM

```yaml
jellyfin:
  limits: {cpus: '4.0', memory: 4GB}
```

**Total**: 4GB (leaves 4GB VM overhead)

## Troubleshooting Resource Issues

### Container Using Too Much CPU

**Diagnosis**:

```bash
# Identify high CPU container
podman stats --no-stream | sort -k3 -rh

# Check what process inside container is using CPU
podman exec sonarr top -bn1
```

**Solutions**:

1. **Set CPU limit**:

   ```bash
   podman update --cpus="1.0" sonarr
   ```

2. **Check for infinite loops/bugs**:

   ```bash
   podman logs sonarr | grep -i "error\|warning"
   ```

3. **Restart container**:

   ```bash
   podman restart sonarr
   ```

### Container Running Out of Memory (OOM)

**Symptoms**:

- Container keeps restarting
- Logs show "Killed" or "OOM"
- `podman inspect` shows OOMKilled: true

**Diagnosis**:

```bash
# Check OOM status
podman inspect sonarr | grep OOMKilled

# Check memory limit
podman stats sonarr --no-stream

# Check system OOM logs
sudo journalctl -k | grep -i "out of memory"
```

**Solutions**:

1. **Increase memory limit**:

   ```bash
   podman update --memory="1g" --memory-swap="1g" sonarr
   ```

2. **Restart container** (clears memory leaks):

   ```bash
   podman restart sonarr
   ```

3. **Check for memory leaks**:
   - Update container to latest version
   - Check application logs for issues

### Disk I/O Saturation

**Diagnosis**:

```bash
# Check I/O stats
podman stats --no-stream --format "table {{.Container}}\t{{.BlockIO}}"

# System-wide I/O
sudo iostat -x 1 5

# Check which process causing I/O
sudo iotop
```

**Solutions**:

1. **Limit I/O weight** (cgroups v2):

   ```yaml
   deploy:
     resources:
       limits:
         blkio_weight: 500  # 100-1000, lower = less priority
   ```

2. **Spread I/O-heavy tasks**:
   - Schedule Sonarr/Radarr scans at different times
   - Limit concurrent downloads in qBittorrent

3. **Use faster storage** (if possible):
   - SSD for Docker volumes
   - Keep NFS for media only

### High Network Usage

**Diagnosis**:

```bash
# Check container network usage
podman stats --format "table {{.Container}}\t{{.NetIO}}"

# Detailed network stats
podman exec sonarr cat /proc/net/dev
```

**Solutions**:

1. **Limit bandwidth in application**:
   - qBittorrent: Tools → Options → Connection → Rate Limits
   - SABnzbd: Config → Servers → Speed Limit

2. **Use QoS on router** (external to Docker)

### Resource Contention Between Containers

**Symptoms**:

- Multiple containers slow simultaneously
- VM running at 100% CPU/memory

**Diagnosis**:

```bash
# Check all containers
podman stats

# Check VM resources
free -h
top
```

**Solutions**:

1. **Set limits on all containers** (prevents monopolization)

2. **Prioritize critical services** with CPU shares:

   ```yaml
   deploy:
     resources:
       limits:
         cpus: '1.0'
       reservations:
         cpus: '0.5'  # Guaranteed allocation
   ```

3. **Consider adding VM resources**:
   - Increase VM RAM/CPU in Proxmox
   - Or distribute services across more VMs

## Best Practices

1. **Start without limits**, monitor for 1-2 weeks to understand baseline
2. **Set limits 20-30% above observed peaks** (allows growth)
3. **Reserve resources for critical services** (Jellyfin, qBittorrent)
4. **Monitor regularly** with `podman stats` and Grafana (if deployed)
5. **Update limits as workload changes** (more shows = more Sonarr RAM)
6. **Test limits don't cause OOM** after applying
7. **Leave 20-30% VM resources unused** for OS and spikes

## Automation and Monitoring

### Log Resource Usage

```bash
# Cron job to log daily stats
echo "0 8 * * * podman stats --no-stream >> /var/log/podman-stats.log" | crontab -
```

### Alert on High Resource Usage

```bash
# Simple script to check CPU usage
#!/bin/bash
THRESHOLD=80
CPU=$(podman stats --no-stream sonarr --format "{{.CPUPerc}}" | sed 's/%//')

if (( $(echo "$CPU > $THRESHOLD" | bc -l) )); then
  echo "Alert: Sonarr CPU at ${CPU}%" | mail -s "High CPU" user@example.com
fi
```

### Grafana + Prometheus (Optional)

For advanced monitoring, deploy Grafana with cAdvisor:

- Real-time dashboards
- Historical trends
- Alert rules
- See Plan B for monitoring stack deployment

## See Also

- [Resource Allocation Reference](../reference/vm-specifications.md)
- [Common Issues](../troubleshooting/common-issues.md)
