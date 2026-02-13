# Lancache Maintenance

Maintenance procedures for Lancache game download caching service.

> **IMPORTANT**: Lancache runs as a **rootful Podman container** on the lancache VM (192.168.40.18).
> This is one of the few services NOT using rootless Podman due to port 53/80/443 requirements.
> Use `sudo systemctl` commands, NOT `systemctl --user`.

## Overview

- **VM**: lancache (VMID 700, 192.168.40.18)
- **Ports**: 80 (HTTP cache), 443 (SNI proxy), 53 (DNS)
- **Components**: Lancache Monolithic, Lancache DNS
- **Cache Path**: `/opt/lancache/cache/`
- **Logs Path**: `/opt/lancache/logs/`
- **Quadlet Files**: `/etc/containers/systemd/lancache-*.container`

## Routine Maintenance

### Daily Checks

```bash
# SSH to Lancache VM
ssh -i ~/.ssh/ansible_homelab ansible@lancache.discus-moth.ts.net

# Check services are running
sudo systemctl status lancache-monolithic lancache-dns

# Quick cache stats
du -sh /opt/lancache/cache/

# Check for recent cache hits
sudo journalctl -u lancache-monolithic --since "1 hour ago" | grep -c "HIT"
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /opt/lancache/cache
   du -sh /opt/lancache/cache/*
   ```

2. **Review cache effectiveness**:

   ```bash
   # Count hits vs misses (last 24 hours)
   sudo journalctl -u lancache-monolithic --since "24 hours ago" | grep -c "HIT"
   sudo journalctl -u lancache-monolithic --since "24 hours ago" | grep -c "MISS"
   ```

3. **Check DNS resolution**:

   ```bash
   # Test DNS is redirecting gaming CDNs
   nslookup steamcdn-a.akamaihd.net 192.168.40.18
   # Should return 192.168.40.18
   ```

4. **Review logs for errors**:

   ```bash
   sudo journalctl -u lancache-monolithic --since "1 week ago" | grep -i error | tail -20
   sudo journalctl -u lancache-dns --since "1 week ago" | grep -i error | tail -20
   ```

### Monthly Maintenance

1. **Update containers**
2. **Review cache size and adjust if needed**
3. **Clean up old logs**
4. **Verify client DNS configuration**

## Service Management

### Check Status

```bash
# Both services (rootful)
sudo systemctl status lancache-monolithic lancache-dns

# Container status
sudo podman ps --filter "name=lancache"
```

### View Logs

```bash
# Follow monolithic logs (shows HIT/MISS)
sudo journalctl -u lancache-monolithic -f

# DNS server logs
sudo journalctl -u lancache-dns -f

# Container logs directly
sudo podman logs -f lancache-monolithic
sudo podman logs -f lancache-dns

# Search for specific patterns
sudo journalctl -u lancache-monolithic | grep -i "steam" | tail -20
```

### Start/Stop/Restart

```bash
# Stop services
sudo systemctl stop lancache-monolithic lancache-dns

# Start services
sudo systemctl start lancache-dns lancache-monolithic

# Restart both
sudo systemctl restart lancache-dns lancache-monolithic

# Enable auto-start
sudo systemctl enable lancache-monolithic lancache-dns
```

## Cache Management

### Check Cache Size

```bash
# Total cache size
du -sh /opt/lancache/cache

# Size by platform/CDN
du -sh /opt/lancache/cache/*

# Disk usage percentage
df -h /opt/lancache/cache
```

### Monitor Cache Effectiveness

```bash
# Calculate hit ratio
HITS=$(sudo journalctl -u lancache-monolithic --since "24 hours ago" | grep -c "HIT")
MISSES=$(sudo journalctl -u lancache-monolithic --since "24 hours ago" | grep -c "MISS")
echo "Hits: $HITS, Misses: $MISSES"
echo "Hit ratio: $(echo "scale=2; $HITS * 100 / ($HITS + $MISSES)" | bc)%"
```

### Clear Specific Platform Cache

```bash
# Stop service first
sudo systemctl stop lancache-monolithic

# Clear Steam cache only
sudo rm -rf /opt/lancache/cache/steam/*

# Clear Epic Games cache
sudo rm -rf /opt/lancache/cache/epicgames/*

# Clear all game caches (keeps structure)
sudo find /opt/lancache/cache -mindepth 1 -maxdepth 1 -type d -exec rm -rf {}/* \;

# Start service
sudo systemctl start lancache-monolithic
```

### Clear Entire Cache

```bash
# Stop service
sudo systemctl stop lancache-monolithic

# Remove all cache data
sudo rm -rf /opt/lancache/cache/*

# Restart
sudo systemctl start lancache-monolithic
```

### Adjust Cache Size Limit

Edit the Quadlet file:

```bash
sudo nano /etc/containers/systemd/lancache-monolithic.container
```

Modify the environment variable:

```ini
Environment=CACHE_DISK_SIZE=1000g  # Change to desired size
```

Apply changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart lancache-monolithic
```

## Container Updates

### Update Lancache Containers

```bash
# SSH to Lancache VM
ssh -i ~/.ssh/ansible_homelab ansible@lancache.discus-moth.ts.net

# Pull latest images
sudo podman pull docker.io/lancachenet/monolithic:latest
sudo podman pull docker.io/lancachenet/lancache-dns:latest

# Restart services
sudo systemctl restart lancache-dns lancache-monolithic

# Verify running
sudo podman ps --filter "name=lancache"
```

### Rollback After Failed Update

```bash
# Stop services
sudo systemctl stop lancache-monolithic lancache-dns

# Find previous images
sudo podman images | grep lancache

# Tag previous version
sudo podman tag <previous-monolithic-id> docker.io/lancachenet/monolithic:rollback
sudo podman tag <previous-dns-id> docker.io/lancachenet/lancache-dns:rollback

# Edit Quadlet files to use rollback tags
sudo nano /etc/containers/systemd/lancache-monolithic.container
sudo nano /etc/containers/systemd/lancache-dns.container

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start lancache-dns lancache-monolithic
```

## DNS Configuration

### Verify DNS Redirection

```bash
# Test from local machine
nslookup steamcdn-a.akamaihd.net 192.168.40.18
# Should return: 192.168.40.18

# Test Epic Games
nslookup cdn1.epicgames.com 192.168.40.18
# Should return: 192.168.40.18

# Test upstream DNS (non-gaming)
nslookup google.com 192.168.40.18
# Should return Google's actual IPs
```

### DNS Configuration Options

Edit Quadlet file:

```bash
sudo nano /etc/containers/systemd/lancache-dns.container
```

Key environment variables:

```ini
# Upstream DNS for non-cached requests
Environment=UPSTREAM_DNS=9.9.9.9

# Cache server IP (this VM)
Environment=LANCACHE_IP=192.168.40.18

# Enable generic caching for all supported CDNs
Environment=USE_GENERIC_CACHE=true

# Disable specific platforms (if needed)
# Environment=DISABLE_STEAM=true
# Environment=DISABLE_EPICGAMES=true
```

Apply changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart lancache-dns
```

## Log Management

### View Logs

```bash
# Real-time cache activity
sudo journalctl -u lancache-monolithic -f | grep -E "HIT|MISS"

# Search for specific game/platform
sudo journalctl -u lancache-monolithic | grep -i "steam" | tail -50

# DNS queries
sudo journalctl -u lancache-dns -f
```

### Log File Location

Lancache also writes logs to `/opt/lancache/logs/`:

```bash
ls -la /opt/lancache/logs/

# View access logs
tail -f /opt/lancache/logs/access.log

# View error logs
tail -f /opt/lancache/logs/error.log
```

### Clean Old Logs

```bash
# Check log size
du -sh /opt/lancache/logs/

# Remove logs older than 30 days
sudo find /opt/lancache/logs -name "*.log" -mtime +30 -delete

# Rotate current logs (stop, clear, start)
sudo systemctl stop lancache-monolithic
sudo truncate -s 0 /opt/lancache/logs/*.log
sudo systemctl start lancache-monolithic
```

## Backup Procedures

### Backup Configuration

Cache data doesn't need backup (can be re-downloaded), but configuration should be preserved:

```bash
#!/bin/bash
# Save as ~/backup-lancache-config.sh

BACKUP_DIR="/mnt/data/backups/lancache"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Backup Quadlet files
sudo tar -czf "$BACKUP_DIR/lancache-config-${DATE}.tar.gz" \
  -C /etc/containers/systemd \
  lancache-monolithic.container \
  lancache-dns.container

# Copy to user-accessible location
sudo chown ansible:ansible "$BACKUP_DIR/lancache-config-${DATE}.tar.gz"

echo "Backup complete: $BACKUP_DIR/lancache-config-${DATE}.tar.gz"
```

### Restore Configuration

```bash
# Extract backup
sudo tar -xzf /mnt/data/backups/lancache/lancache-config-YYYYMMDD.tar.gz \
  -C /etc/containers/systemd/

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart lancache-dns lancache-monolithic
```

### Optional: Backup Cache

For large caches, backup may be worthwhile (saves re-download time):

```bash
# This can take a long time for large caches!
sudo systemctl stop lancache-monolithic

sudo tar -czf /mnt/backup/lancache-cache-$(date +%Y%m%d).tar.gz \
  -C /opt/lancache cache

sudo systemctl start lancache-monolithic
```

## Performance Tuning

### Memory Allocation

Increase nginx cache metadata memory for better performance:

```bash
sudo nano /etc/containers/systemd/lancache-monolithic.container
```

```ini
# For large caches (>500GB)
Environment=CACHE_MEM_SIZE=2g

# For very large caches (>1TB)
Environment=CACHE_MEM_SIZE=4g
```

### Worker Processes

Match worker processes to available CPU cores:

```ini
Environment=NGINX_WORKER_PROCESSES=4  # For 4 CPU cores
```

### Disk I/O Optimization

If using dedicated disk for cache:

```bash
# Add noatime to reduce disk writes
# Edit /etc/fstab:
/dev/sdb1 /opt/lancache/cache ext4 defaults,noatime 0 2
```

## Resource Monitoring

### Check Resource Usage

```bash
# Container resource usage
sudo podman stats --no-stream lancache-monolithic lancache-dns

# System resources
free -h
df -h /opt/lancache/cache
```

### Monitor Network Throughput

```bash
# Network I/O
iftop -i eth0

# During game downloads, expect high traffic
```

## Troubleshooting Common Issues

### DNS Not Redirecting

```bash
# Check DNS container is running
sudo systemctl status lancache-dns

# Verify DNS port is listening
sudo ss -ulnp | grep 53

# Check DNS logs
sudo journalctl -u lancache-dns | tail -50

# Test resolution
nslookup steamcdn-a.akamaihd.net 192.168.40.18
```

### Cache Misses When Should Hit

```bash
# Check cache file exists
find /opt/lancache/cache -name "*<filename>*" -ls

# Verify cache size limit isn't reached
du -sh /opt/lancache/cache
# Compare to CACHE_DISK_SIZE setting

# Check cache age setting
grep CACHE_MAX_AGE /etc/containers/systemd/lancache-monolithic.container
```

### Service Won't Start

```bash
# Check logs for errors
sudo journalctl -u lancache-monolithic -n 100

# Verify Quadlet file syntax
cat /etc/containers/systemd/lancache-monolithic.container

# Check for port conflicts
sudo ss -tlnp | grep -E "80|443|53"

# Reload systemd
sudo systemctl daemon-reload
```

### Slow Download Speeds

1. Check disk I/O is not saturated:

   ```bash
   iostat -x 1 5
   ```

2. Verify memory is sufficient:

   ```bash
   free -h
   ```

3. Check network isn't bottleneck:

   ```bash
   iftop -i eth0
   ```

4. Consider SSD for cache storage

### Container Network Issues

```bash
# Verify host network mode
sudo podman inspect lancache-monolithic | grep NetworkMode
# Should show: "host"

# Check firewall
sudo ufw status | grep -E "80|443|53"
```

## Client Verification

### Test from Gaming PC

```bash
# Windows: Check DNS settings
ipconfig /all | findstr DNS

# Test resolution
nslookup steamcdn-a.akamaihd.net

# Should return Lancache IP (192.168.40.18)
```

### Verify Cache is Being Used

1. Start a game download on Steam
2. Watch Lancache logs:

   ```bash
   sudo journalctl -u lancache-monolithic -f | grep -i steam
   ```

3. First download shows MISS, subsequent downloads show HIT

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Service health check | Daily | Automated via monitoring |
| Check disk space | Weekly | Alert if >80% |
| Review cache hit ratio | Weekly | Should be >50% for repeat downloads |
| Container updates | Monthly | Check for new versions |
| Log cleanup | Monthly | Remove logs >30 days |
| Config backup | Monthly | Quadlet files |
| Clear old cache entries | Quarterly | If disk space constrained |

## See Also

- [Lancache Configuration](../configuration/lancache-setup.md)
- [Lancache Troubleshooting](../troubleshooting/lancache.md)
- [AdGuard Home Configuration](../configuration/adguard-home.md) - DNS integration
- [Service Endpoints](../configuration/service-endpoints.md)
