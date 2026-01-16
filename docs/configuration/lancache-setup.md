# Lancache Configuration

Lancache is a game download caching service that stores game files locally, dramatically reducing bandwidth usage and
speeding up downloads for Steam, Epic Games, Origin, Battle.net, and other gaming platforms.

> **IMPORTANT**: Lancache runs as a **rootful Podman container** on the lancache VM (192.168.0.18).
> This is one of the few services NOT using rootless Podman due to port 53/80/443 requirements.

## Overview

- **VM**: lancache (VMID 700, 192.168.0.18)
- **Ports**: 80 (HTTP cache), 443 (SNI proxy), 53 (DNS)
- **Deployment**: Rootful Podman with systemd
- **Playbook**: [`playbooks/core/deploy-lancache.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/deploy-lancache.yml)

## Architecture

Lancache consists of two main components:

1. **Lancache Monolithic** - The cache server (nginx-based)
2. **Lancache DNS** - DNS server that redirects gaming CDNs to the cache

```text
┌─────────────────────────────────────────────────────────────────┐
│                        Lancache VM (192.168.0.18)               │
│                                                                 │
│  ┌─────────────────┐       ┌─────────────────────────────────┐  │
│  │  Lancache DNS   │       │     Lancache Monolithic         │  │
│  │   Port 53       │       │     Port 80 (HTTP)              │  │
│  │                 │       │     Port 443 (SNI Proxy)        │  │
│  │ Redirects CDN   │──────▶│                                 │  │
│  │ queries to      │       │     ┌─────────────────────┐     │  │
│  │ cache server    │       │     │   Cache Storage     │     │  │
│  └─────────────────┘       │     │  /opt/lancache/     │     │  │
│                            │     │       cache/        │     │  │
│                            │     └─────────────────────┘     │  │
│                            └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Supported Platforms

Lancache caches downloads from:

- **Steam** (Valve)
- **Epic Games Store**
- **Origin/EA App**
- **Battle.net** (Blizzard)
- **Uplay** (Ubisoft)
- **Xbox/Microsoft Store**
- **Windows Updates**
- **PlayStation Updates**
- **Nintendo Switch Updates**
- **GOG**
- **Rockstar Games**
- **ArenaNet** (Guild Wars 2)
- **Riot Games** (League of Legends, Valorant)

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy Lancache
./bin/runtime/ansible-run.sh playbooks/core/deploy-lancache.yml
```

### Quadlet Configuration Files

Located at `/etc/containers/systemd/` on the lancache VM:

**lancache-monolithic.container**:

```ini
[Unit]
Description=Lancache Monolithic Cache Server
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/lancachenet/monolithic:latest
ContainerName=lancache-monolithic
Network=host
Volume=/opt/lancache/cache:/data/cache:Z
Volume=/opt/lancache/logs:/data/logs:Z
Environment=CACHE_MEM_SIZE=500m
Environment=CACHE_DISK_SIZE=500g
Environment=CACHE_MAX_AGE=3650d
Environment=UPSTREAM_DNS=9.9.9.9

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

**lancache-dns.container**:

```ini
[Unit]
Description=Lancache DNS Server
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/lancachenet/lancache-dns:latest
ContainerName=lancache-dns
Network=host
Environment=UPSTREAM_DNS=9.9.9.9
Environment=USE_GENERIC_CACHE=true
Environment=LANCACHE_IP=192.168.0.18

[Service]
Restart=always
TimeoutStartSec=60

[Install]
WantedBy=default.target
```

## Configuration Options

### Environment Variables

#### Lancache Monolithic

| Variable | Default | Description |
|----------|---------|-------------|
| `CACHE_MEM_SIZE` | `500m` | RAM for nginx cache metadata |
| `CACHE_DISK_SIZE` | `1000g` | Maximum disk cache size |
| `CACHE_MAX_AGE` | `3650d` | How long to keep cached files |
| `UPSTREAM_DNS` | `8.8.8.8` | DNS for non-cached requests |
| `CACHE_SLICE_SIZE` | `1m` | Size of cache file slices |
| `NGINX_WORKER_PROCESSES` | `auto` | Number of worker processes |

#### Lancache DNS

| Variable | Default | Description |
|----------|---------|-------------|
| `UPSTREAM_DNS` | `8.8.8.8` | Upstream DNS server |
| `USE_GENERIC_CACHE` | `true` | Enable caching for all supported CDNs |
| `LANCACHE_IP` | Required | IP address of cache server |
| `DISABLE_*` | `false` | Disable specific CDNs (e.g., `DISABLE_STEAM=true`) |

### Adjusting Cache Size

Edit the Quadlet file:

```bash
sudo nano /etc/containers/systemd/lancache-monolithic.container
```

Modify:

```ini
Environment=CACHE_DISK_SIZE=1000g  # Adjust as needed
```

Reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart lancache-monolithic
```

### Cache Storage Location

Default: `/opt/lancache/cache/`

For best performance:

- Use SSD storage if possible
- Dedicate a separate disk/partition for cache
- Ensure sufficient IOPS for concurrent clients

## Client Configuration

For Lancache to work, clients must use Lancache DNS (192.168.0.18) for DNS resolution.

### Option 1: DHCP/Router Configuration (Recommended)

Configure your router/DHCP server to assign Lancache DNS to gaming devices:

1. Access router admin interface
2. Find DHCP settings
3. Set primary DNS to: `192.168.0.18`
4. Set secondary DNS to: `9.9.9.9` (fallback)

### Option 2: Per-Device DNS

**Windows**:

1. Network Settings → Ethernet/Wi-Fi → IP Settings → Edit
2. DNS: Manual
3. Preferred DNS: `192.168.0.18`
4. Alternate DNS: `9.9.9.9`

**Linux**:

```bash
# NetworkManager (GUI or nmcli)
nmcli con mod "Connection Name" ipv4.dns "192.168.0.18 9.9.9.9"

# Or edit /etc/resolv.conf (temporary)
sudo nano /etc/resolv.conf
# nameserver 192.168.0.18
# nameserver 9.9.9.9
```

**Gaming Consoles**:

- PlayStation: Settings → Network → Set Up → Custom → DNS Manual
- Xbox: Settings → Network → Advanced → DNS Manual
- Nintendo Switch: System Settings → Internet → DNS Settings → Manual

### Option 3: AdGuard Home Integration

If using AdGuard Home (192.168.0.15), configure DNS rewrites:

1. Open AdGuard Home: http://nas.discus-moth.ts.net
2. Go to Filters → DNS rewrites
3. Add rewrites for gaming CDNs to point to Lancache IP

Example rewrites:

```text
*.steamcontent.com → 192.168.0.18
*.akamaihd.net → 192.168.0.18
cdn*.epicgames.com → 192.168.0.18
```

## Testing the Cache

### Verify DNS Redirection

```bash
# From a client using Lancache DNS
nslookup steamcdn-a.akamaihd.net

# Should return 192.168.0.18
```

### Test Cache Operation

1. **Start a game download** (e.g., Steam)
2. **Watch cache logs**:

   ```bash
   ssh ansible@lancache.discus-moth.ts.net
   sudo journalctl -u lancache-monolithic -f
   ```

3. **Look for HIT/MISS entries**:
   - First download: `MISS` (fetched from internet)
   - Second download: `HIT` (served from cache)

### Measure Cache Effectiveness

```bash
# Check cache size
du -sh /opt/lancache/cache

# Count hits vs misses (last hour)
sudo journalctl -u lancache-monolithic --since "1 hour ago" | grep -c "HIT"
sudo journalctl -u lancache-monolithic --since "1 hour ago" | grep -c "MISS"
```

## Monitoring

### Cache Statistics

```bash
# Total cache size
du -sh /opt/lancache/cache

# Size by CDN/platform
du -sh /opt/lancache/cache/*

# Disk usage percentage
df -h /opt/lancache/cache
```

### Service Health

```bash
# Check both services
sudo systemctl status lancache-monolithic lancache-dns

# Resource usage
sudo podman stats lancache-monolithic lancache-dns --no-stream
```

### Prometheus Integration

Lancache can be monitored with Prometheus using the nginx exporter:

- Metrics endpoint: `http://192.168.0.18:9113/metrics`
- Grafana dashboard: Search for "nginx" dashboards

## Performance Tuning

### Memory Allocation

Increase `CACHE_MEM_SIZE` for better metadata caching:

```ini
Environment=CACHE_MEM_SIZE=2g  # For large caches
```

### Worker Processes

Match worker processes to CPU cores:

```ini
Environment=NGINX_WORKER_PROCESSES=4
```

### Disk I/O Optimization

1. **Use SSD** for cache storage
2. **Mount with noatime**: Reduces disk writes

   ```bash
   # In /etc/fstab
   /dev/sdb1 /opt/lancache/cache ext4 defaults,noatime 0 2
   ```

3. **Consider RAID0** for throughput (if acceptable risk)

## Maintenance

### Clear Cache

```bash
# Stop services
sudo systemctl stop lancache-monolithic

# Clear specific platform
sudo rm -rf /opt/lancache/cache/steam/*

# Or clear all
sudo rm -rf /opt/lancache/cache/*

# Restart
sudo systemctl start lancache-monolithic
```

### Update Containers

```bash
# Pull latest images
sudo podman pull docker.io/lancachenet/monolithic:latest
sudo podman pull docker.io/lancachenet/lancache-dns:latest

# Restart services
sudo systemctl restart lancache-monolithic lancache-dns
```

### Backup Cache (Optional)

Cache can be backed up for restoration:

```bash
# Stop service first
sudo systemctl stop lancache-monolithic

# Create backup
sudo tar -czf /mnt/backup/lancache-cache-$(date +%Y%m%d).tar.gz -C /opt/lancache cache

# Restart
sudo systemctl start lancache-monolithic
```

## Security Considerations

1. **Internal Network Only**: Lancache should only be accessible from trusted networks
2. **No Authentication**: Lancache doesn't require authentication (by design)
3. **Firewall Rules**: Restrict access to LAN/Tailscale networks

```bash
# UFW rules (already configured via playbook)
sudo ufw allow from 192.168.0.0/24 to any port 80
sudo ufw allow from 192.168.0.0/24 to any port 443
sudo ufw allow from 192.168.0.0/24 to any port 53
```

## See Also

- [Lancache Troubleshooting](../troubleshooting/lancache.md)
- [Service Endpoints](service-endpoints.md)
- [AdGuard Home Configuration](adguard-home.md)
- [Networking Configuration](networking.md)
