# Lancache Troubleshooting

Lancache is a game download caching service that stores game files locally, dramatically speeding up downloads for
Steam, Epic Games, Origin, Battle.net, and other gaming platforms.

> **IMPORTANT**: Lancache runs as a **rootful Podman container** on the lancache VM (192.168.0.18).
> Use `sudo systemctl` and `sudo podman` commands. This is one of the few services NOT using rootless Podman.

## Overview

- **VM**: lancache (192.168.0.18)
- **Ports**: 80 (HTTP cache), 443 (SNI proxy)
- **Container**: lancache-monolithic
- **DNS Container**: lancache-dns
- **Config Path**: `/opt/lancache/`
- **Cache Path**: `/opt/lancache/cache/`
- **Deployment**: Rootful Podman (requires sudo)
- **Purpose**: Cache game downloads from Steam, Epic, Origin, etc.

## Access

- **Tailscale**: http://lancache.discus-moth.ts.net:80
- **Local Network**: http://192.168.0.18:80

## Quick Diagnostics

```bash
# SSH to lancache VM
ssh -i ~/.ssh/ansible_homelab ansible@lancache.discus-moth.ts.net

# Check service status (rootful - requires sudo)
sudo systemctl status lancache-monolithic
sudo systemctl status lancache-dns

# View logs
sudo journalctl -u lancache-monolithic -f
sudo journalctl -u lancache-dns -f

# Check if containers are running
sudo podman ps | grep lancache

# Check cache disk usage
df -h /opt/lancache/cache

# Check cache statistics
ls -lh /opt/lancache/cache/
du -sh /opt/lancache/cache/*
```

## How Lancache Works

1. **DNS Redirection**: Lancache DNS intercepts requests to game CDNs
2. **First Download**: Cache miss → downloads from internet, stores locally
3. **Subsequent Downloads**: Cache hit → serves from local cache instantly
4. **Transparent**: Works without game client configuration changes

### Network Flow

```text
[Game Client] → DNS Query → [Lancache DNS] → Redirect to [Lancache Cache]
                                                    ↓
                                            Cache Hit? → Serve locally
                                            Cache Miss? → Fetch from CDN → Store → Serve
```

## Common Issues

### 1. Lancache Not Caching Downloads

**Symptoms**:

- Downloads still going to internet
- No cache growth
- Same files downloaded multiple times

**Diagnosis**:

```bash
# Check DNS is resolving to Lancache
nslookup steamcdn-a.akamaihd.net 192.168.0.18
# Should return 192.168.0.18

# Check cache container is running
sudo podman ps | grep lancache-monolithic

# Check cache logs during download
sudo journalctl -u lancache-monolithic -f
# Should show HIT or MISS entries

# Verify cache directory is writable
sudo touch /opt/lancache/cache/test && sudo rm /opt/lancache/cache/test
```

**Solutions**:

1. **Client not using Lancache DNS**:
   - Configure clients to use Lancache DNS (192.168.0.18)
   - Or set Lancache DNS as primary in router/DHCP
   - Or configure AdGuard Home to forward to Lancache for gaming domains

2. **DNS container not running**:

   ```bash
   sudo systemctl start lancache-dns
   sudo systemctl enable lancache-dns
   ```

3. **HTTPS traffic not being intercepted**:
   - Lancache uses SNI proxy for HTTPS
   - Check port 443 is listening: `sudo netstat -tulpn | grep 443`

4. **Cache directory permissions**:

   ```bash
   sudo chown -R root:root /opt/lancache/cache
   sudo chmod -R 755 /opt/lancache/cache
   ```

### 2. DNS Resolution Not Working

**Symptoms**:

- Game clients can't resolve CDN hostnames
- DNS queries timing out
- "Server not found" errors in games

**Diagnosis**:

```bash
# Test DNS resolution
dig @192.168.0.18 steamcdn-a.akamaihd.net

# Check DNS container
sudo systemctl status lancache-dns
sudo journalctl -u lancache-dns -n 100

# Verify DNS is listening on port 53
sudo netstat -tulpn | grep :53
```

**Solutions**:

1. **DNS container not running**:

   ```bash
   sudo systemctl start lancache-dns
   sudo journalctl -u lancache-dns -f
   ```

2. **Port 53 conflict**:

   ```bash
   # Check what's using port 53
   sudo lsof -i :53

   # If systemd-resolved is conflicting
   sudo systemctl disable systemd-resolved
   # Edit /etc/resolv.conf to use upstream DNS
   ```

3. **Firewall blocking DNS**:

   ```bash
   sudo ufw allow 53/tcp
   sudo ufw allow 53/udp
   sudo ufw reload
   ```

4. **Upstream DNS not configured**:

   ```bash
   # Check environment variables for upstream DNS
   sudo podman inspect lancache-dns | grep -i dns
   # Should have UPSTREAM_DNS set (e.g., 9.9.9.9)
   ```

### 3. Cache Disk Full

**Symptoms**:

- New downloads not caching
- "No space left on device" errors
- Cache percentage at 100%

**Diagnosis**:

```bash
# Check disk usage
df -h /opt/lancache/cache

# Check cache size by service
du -sh /opt/lancache/cache/*

# Check for specific large files
find /opt/lancache/cache -type f -size +10G -exec ls -lh {} \;
```

**Solutions**:

1. **Increase cache storage**:
   - Expand VM disk in Proxmox
   - Grow partition and filesystem

2. **Configure cache limits**:
   - Set `CACHE_MAX_SIZE` environment variable
   - Default is unlimited (fills available space)

   ```bash
   # Edit Quadlet file
   sudo nano /etc/containers/systemd/lancache-monolithic.container

   # Add or modify:
   # Environment=CACHE_MAX_SIZE=500g
   ```

3. **Clear old cache**:

   ```bash
   # Stop service
   sudo systemctl stop lancache-monolithic

   # Clear specific game cache (example: Steam)
   sudo rm -rf /opt/lancache/cache/steam/*

   # Or clear all cache (last resort)
   sudo rm -rf /opt/lancache/cache/*

   # Start service
   sudo systemctl start lancache-monolithic
   ```

4. **Enable automatic cleanup**:
   - Configure nginx cache manager with `inactive` setting
   - Old files automatically removed after not being accessed

### 4. Slow Cache Performance

**Symptoms**:

- Cached downloads slower than expected
- High latency from cache
- CPU/disk bottlenecks

**Diagnosis**:

```bash
# Check disk I/O
iostat -x 1 5

# Check container resource usage
sudo podman stats lancache-monolithic --no-stream

# Check network throughput
iftop -i eth0
```

**Solutions**:

1. **Disk I/O bottleneck**:
   - Use SSD for cache storage if possible
   - Check disk health: `sudo smartctl -a /dev/sdX`
   - Consider RAID for better throughput

2. **Memory constraints**:
   - Increase VM RAM for better file caching
   - Lancache benefits from OS page cache

3. **Network bottleneck**:
   - Verify VM has sufficient network bandwidth
   - Check for network congestion

### 5. Service Won't Start

**Symptoms**:

- Container fails to start
- systemctl shows failed status
- Exit code non-zero

**Diagnosis**:

```bash
# Check service status
sudo systemctl status lancache-monolithic

# Check recent logs
sudo journalctl -u lancache-monolithic -n 200

# Check container directly
sudo podman inspect lancache-monolithic | grep -i exit
```

**Solutions**:

1. **Image not pulled**:

   ```bash
   sudo podman pull docker.io/lancachenet/monolithic:latest
   sudo podman pull docker.io/lancachenet/lancache-dns:latest
   ```

2. **Port already in use**:

   ```bash
   # Check ports 80 and 443
   sudo lsof -i :80
   sudo lsof -i :443

   # Stop conflicting service
   ```

3. **Cache directory missing**:

   ```bash
   sudo mkdir -p /opt/lancache/cache
   sudo mkdir -p /opt/lancache/logs
   sudo chown -R root:root /opt/lancache
   ```

4. **Reload systemd and restart**:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart lancache-monolithic lancache-dns
   ```

### 6. Specific Game/Platform Not Caching

**Symptoms**:

- Steam caching but not Epic
- Only some CDNs being intercepted
- Missing cache entries for certain games

**Diagnosis**:

```bash
# Check which CDNs are configured
sudo podman exec lancache-dns cat /etc/dnsmasq.d/*.conf

# Test specific CDN resolution
dig @192.168.0.18 cdn1.epicgames.com

# Check cache logs for platform
sudo journalctl -u lancache-monolithic | grep -i epic
```

**Solutions**:

1. **CDN not in DNS configuration**:
   - Lancache DNS includes common CDNs by default
   - Check for updates to CDN list
   - Update lancache-dns container image

2. **Platform using HTTPS with certificate pinning**:
   - Some platforms can't be cached due to certificate pinning
   - Lancache cannot cache these (security feature)

3. **CDN hostname changed**:
   - CDN providers occasionally change hostnames
   - Update lancache-dns to latest version

## Supported Platforms

Lancache typically caches these platforms:

- **Steam** (Valve)
- **Epic Games Store**
- **Origin/EA App**
- **Battle.net** (Blizzard)
- **Uplay** (Ubisoft)
- **Windows Updates**
- **Xbox/Microsoft Store**
- **PlayStation Updates**
- **Nintendo Switch Updates**
- **GOG**
- **ArenaNet** (Guild Wars 2)

## Cache Statistics

### View Cache Usage

```bash
# Total cache size
du -sh /opt/lancache/cache

# Size by platform/CDN
du -sh /opt/lancache/cache/*

# Number of cached files
find /opt/lancache/cache -type f | wc -l
```

### Monitor Cache Hits/Misses

```bash
# Watch logs for HIT/MISS ratio
sudo journalctl -u lancache-monolithic -f | grep -E "HIT|MISS"

# Count hits vs misses
sudo journalctl -u lancache-monolithic --since "1 hour ago" | grep -c "HIT"
sudo journalctl -u lancache-monolithic --since "1 hour ago" | grep -c "MISS"
```

## Client Configuration

### Option 1: Configure DHCP/Router DNS

Set Lancache DNS (192.168.0.18) as primary DNS for gaming devices.

### Option 2: Per-Device DNS

Configure specific devices to use Lancache DNS:

- **Windows**: Network adapter → IPv4 → DNS: 192.168.0.18
- **Linux**: Edit `/etc/resolv.conf` or NetworkManager
- **Gaming consoles**: Network settings → DNS

### Option 3: AdGuard Home Integration

Configure AdGuard Home to forward gaming domains to Lancache:

```text
# In AdGuard Home DNS rewrites:
*.steamcontent.com → 192.168.0.18
*.akamaihd.net → 192.168.0.18
*.epicgames.com → 192.168.0.18
```

## Update Lancache

```bash
# SSH to lancache VM
ssh -i ~/.ssh/ansible_homelab ansible@lancache.discus-moth.ts.net

# Pull latest images
sudo podman pull docker.io/lancachenet/monolithic:latest
sudo podman pull docker.io/lancachenet/lancache-dns:latest

# Restart services
sudo systemctl restart lancache-monolithic lancache-dns

# Verify version
sudo podman inspect lancachenet/monolithic | grep -i version
```

## Logs and Debugging

### View Logs

```bash
# Cache server logs
sudo journalctl -u lancache-monolithic -f

# DNS server logs
sudo journalctl -u lancache-dns -f

# Combined logs
sudo journalctl -u lancache-monolithic -u lancache-dns -f
```

### Log Patterns

**Cache Hit** (served from local cache):

```text
[INFO] HIT steamcdn-a.akamaihd.net /depot/123456/chunk/...
```

**Cache Miss** (fetched from internet):

```text
[INFO] MISS steamcdn-a.akamaihd.net /depot/123456/chunk/...
```

**DNS Redirect**:

```text
[INFO] Redirecting steamcdn-a.akamaihd.net to 192.168.0.18
```

## See Also

- [Service Endpoints](../configuration/service-endpoints.md)
- [Networking Configuration](../configuration/networking.md)
- [AdGuard Home Configuration](../configuration/adguard-home.md)
- [Common Issues](common-issues.md)
