# Media Services Maintenance

Maintenance procedures for the media services stack: Sonarr, Radarr, Prowlarr, Jellyseerr, Bazarr, Huntarr,
Homarr, Flaresolverr, and Recyclarr.

> **IMPORTANT**: All media services run as **rootless Podman containers with Quadlet** on the media-services VM
> (192.168.0.13). Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

| Service | Port | Purpose |
|---------|------|---------|
| Sonarr | 8989 | TV show management |
| Radarr | 7878 | Movie management |
| Prowlarr | 9696 | Indexer management |
| Jellyseerr | 5055 | Media requests |
| Bazarr | 6767 | Subtitle management |
| Huntarr | 9705 | Missing media hunter |
| Homarr | 7575 | Dashboard |
| Flaresolverr | 8191 | Cloudflare bypass |
| Recyclarr | N/A | Quality profile sync |

## Routine Maintenance

### Daily Checks

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check all services are running
systemctl --user status sonarr radarr prowlarr jellyseerr bazarr

# Quick health check
for svc in sonarr radarr prowlarr jellyseerr bazarr; do
  echo "=== $svc ==="
  curl -s http://localhost:$(case $svc in
    sonarr) echo 8989;;
    radarr) echo 7878;;
    prowlarr) echo 9696;;
    jellyseerr) echo 5055;;
    bazarr) echo 6767;;
  esac)/ping 2>/dev/null || echo "DOWN"
done
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /mnt/data
   du -sh /mnt/data/media/*
   ```

2. **Review logs for errors**:

   ```bash
   journalctl --user -u sonarr --since "1 week ago" | grep -i error | tail -20
   journalctl --user -u radarr --since "1 week ago" | grep -i error | tail -20
   ```

3. **Run Recyclarr sync** (if not scheduled):

   ```bash
   systemctl --user start recyclarr
   journalctl --user -u recyclarr -f
   ```

### Monthly Maintenance

1. **Update containers**
2. **Review and clean up media libraries**
3. **Verify backup integrity**
4. **Check indexer health in Prowlarr**

## Container Updates

### Update All Services

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest images
podman pull docker.io/linuxserver/sonarr:latest
podman pull docker.io/linuxserver/radarr:latest
podman pull docker.io/linuxserver/prowlarr:latest
podman pull docker.io/fallenbagel/jellyseerr:latest
podman pull docker.io/linuxserver/bazarr:latest
podman pull ghcr.io/huntarr/huntarr:latest
podman pull ghcr.io/ajnart/homarr:latest
podman pull ghcr.io/flaresolverr/flaresolverr:latest
podman pull docker.io/recyclarr/recyclarr:latest

# Restart all services
systemctl --user restart sonarr radarr prowlarr jellyseerr bazarr huntarr homarr flaresolverr

# Verify all services are running
podman ps
```

### Update Single Service

```bash
# Example: Update Sonarr
podman pull docker.io/linuxserver/sonarr:latest
systemctl --user restart sonarr

# Check logs for startup issues
journalctl --user -u sonarr -n 50
```

### Rollback After Failed Update

```bash
# Stop service
systemctl --user stop sonarr

# Find previous image
podman images | grep sonarr

# Tag previous image
podman tag <previous-image-id> docker.io/linuxserver/sonarr:rollback

# Update Quadlet file to use rollback tag (temporary)
# Then restart
systemctl --user restart sonarr
```

## Backup Procedures

### Backup All Services

```bash
#!/bin/bash
# Save as ~/backup-media-services.sh

BACKUP_DIR="/mnt/data/backups/media-services"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop services for consistent backup
systemctl --user stop sonarr radarr prowlarr jellyseerr bazarr

# Backup each service config
for svc in sonarr radarr prowlarr jellyseerr bazarr huntarr homarr; do
  if [ -d ~/.config/$svc ]; then
    tar -czf "$BACKUP_DIR/${svc}-${DATE}.tar.gz" -C ~/.config "$svc"
    echo "Backed up $svc"
  fi
done

# Start services
systemctl --user start sonarr radarr prowlarr jellyseerr bazarr

echo "Backup complete: $BACKUP_DIR"
```

### Schedule Automatic Backups

```bash
# Add to crontab
crontab -e

# Weekly backup at 3 AM Sunday
0 3 * * 0 ~/backup-media-services.sh
```

### Restore from Backup

```bash
# Stop the service
systemctl --user stop sonarr

# Remove current config
rm -rf ~/.config/sonarr

# Restore from backup
tar -xzf /mnt/data/backups/media-services/sonarr-YYYYMMDD.tar.gz -C ~/.config/

# Start service
systemctl --user start sonarr
```

## Database Maintenance

### Sonarr/Radarr Database Optimization

```bash
# Stop service
systemctl --user stop sonarr

# Backup database first
cp ~/.config/sonarr/sonarr.db ~/.config/sonarr/sonarr.db.bak

# Vacuum and reindex
sqlite3 ~/.config/sonarr/sonarr.db "VACUUM;"
sqlite3 ~/.config/sonarr/sonarr.db "REINDEX;"

# Start service
systemctl --user start sonarr
```

### Clear Old Logs

```bash
# Sonarr/Radarr keep logs in config directory
find ~/.config/sonarr/logs -name "*.txt" -mtime +30 -delete
find ~/.config/radarr/logs -name "*.txt" -mtime +30 -delete
```

## Indexer Maintenance (Prowlarr)

### Health Check

1. Open Prowlarr: http://media-services.discus-moth.ts.net:9696
2. System → Status → Check for warnings
3. Indexers → Test All

### Refresh Indexers

```bash
# Via API
curl -X POST "http://localhost:9696/api/v1/indexer/testall" \
  -H "X-Api-Key: YOUR_PROWLARR_API_KEY"
```

### Add/Remove Indexers

1. Prowlarr → Indexers → Add
2. Search for indexer
3. Configure credentials
4. Test and save

## Jellyseerr Maintenance

### Sync Users

1. Settings → Users
2. Import Users from Jellyfin
3. Configure permissions

### Clear Request History

1. Requests → Filter by status
2. Bulk delete processed requests

## Recyclarr Sync

### Manual Sync

```bash
# Run Recyclarr
systemctl --user start recyclarr

# Follow logs
journalctl --user -u recyclarr -f
```

### Update Quality Profiles

1. Edit `~/.config/recyclarr/recyclarr.yml`
2. Run sync:

   ```bash
   systemctl --user start recyclarr
   ```

3. Verify in Sonarr/Radarr Settings → Profiles

## Troubleshooting Common Issues

### Service Won't Start

```bash
# Check status
systemctl --user status sonarr

# Check logs
journalctl --user -u sonarr -n 100

# Check container directly
podman logs sonarr

# Verify Quadlet file
cat ~/.config/containers/systemd/sonarr.container
```

### Database Locked

```bash
# Stop service
systemctl --user stop sonarr

# Check for lock files
ls -la ~/.config/sonarr/*.db*

# Remove lock files (if service is stopped)
rm ~/.config/sonarr/*.db-shm ~/.config/sonarr/*.db-wal

# Start service
systemctl --user start sonarr
```

### Disk Space Issues

```bash
# Check disk usage
df -h /mnt/data
du -sh /mnt/data/media/*

# Find large files
find /mnt/data -type f -size +10G -exec ls -lh {} \;

# Clean up container storage
podman system prune -a
```

### Service Not Communicating

```bash
# Test internal connectivity
curl http://localhost:8989  # Sonarr
curl http://localhost:7878  # Radarr
curl http://localhost:9696  # Prowlarr

# Check firewall
sudo ufw status
```

## Performance Monitoring

### Resource Usage

```bash
# Check container resource usage
podman stats --no-stream

# Check specific service
podman stats sonarr --no-stream
```

### Slow Searches

1. Check Prowlarr indexer health
2. Verify FlareSolverr is running (for Cloudflare-protected sites)
3. Check network connectivity to indexers

## API Reference

### Common API Endpoints

| Service | Health Check | API Base |
|---------|-------------|----------|
| Sonarr | `/ping` | `/api/v3/` |
| Radarr | `/ping` | `/api/v3/` |
| Prowlarr | `/ping` | `/api/v1/` |
| Jellyseerr | `/api/v1/status` | `/api/v1/` |
| Bazarr | `/` | `/api/` |

### Example API Calls

```bash
# Sonarr - Get series count
curl -s "http://localhost:8989/api/v3/series" \
  -H "X-Api-Key: YOUR_API_KEY" | jq length

# Radarr - Trigger library refresh
curl -X POST "http://localhost:7878/api/v3/command" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"RefreshMonitoredDownloads"}'
```

## Maintenance Schedule

| Task | Frequency | Time |
|------|-----------|------|
| Health check | Daily | Automated via monitoring |
| Log review | Weekly | Manual |
| Backups | Weekly | 3 AM Sunday |
| Container updates | Monthly | Planned maintenance window |
| Database optimization | Quarterly | During backup |
| Indexer review | Monthly | Manual |

## See Also

- [Sonarr/Radarr Troubleshooting](../troubleshooting/sonarr-radarr.md)
- [Prowlarr Troubleshooting](../troubleshooting/prowlarr.md)
- [Jellyseerr Troubleshooting](../troubleshooting/jellyseerr.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Backup Recovery](backup-recovery.md)
