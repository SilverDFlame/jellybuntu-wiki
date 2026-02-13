# Home Assistant Maintenance

Maintenance procedures for Home Assistant home automation platform.

> **IMPORTANT**: Home Assistant runs as a **rootless Podman container with Quadlet** on the home-assistant VM
> (192.168.20.10). Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: home-assistant (VMID 100, 192.168.20.10)
- **Port**: 8123
- **Config Path**: `~/.config/homeassistant/`
- **Quadlet File**: `~/.config/containers/systemd/homeassistant.container`

## Routine Maintenance

### Daily Checks

```bash
# SSH to Home Assistant VM
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net

# Check service status
systemctl --user status homeassistant

# Quick health check
curl -s http://localhost:8123/api/ | head -1
# Should return: {"message": "API running."}

# Check for errors in logs
journalctl --user -u homeassistant --since "1 hour ago" | grep -i "error\|warning" | tail -10
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /
   du -sh ~/.config/homeassistant/
   du -sh ~/.config/homeassistant/.storage/
   ```

2. **Review logs for issues**:

   ```bash
   journalctl --user -u homeassistant --since "1 week ago" | grep -i error | tail -20
   ```

3. **Check for pending updates**:
   - Access Web UI: http://home-assistant.discus-moth.ts.net:8123
   - Settings → System → Updates

4. **Verify integrations**:
   - Settings → Devices & Services
   - Check for any integrations showing errors

### Monthly Maintenance

1. **Update Home Assistant**
2. **Update HACS integrations**
3. **Clean up database**
4. **Verify backup integrity**
5. **Review automations for issues**

## Service Management

### Check Status

```bash
systemctl --user status homeassistant
```

### View Logs

```bash
# Follow logs in real-time
journalctl --user -u homeassistant -f

# Recent logs
journalctl --user -u homeassistant -n 100

# Errors only
journalctl --user -u homeassistant | grep -i error

# Container logs
podman logs -f homeassistant
```

### Start/Stop/Restart

```bash
# Start
systemctl --user start homeassistant

# Stop
systemctl --user stop homeassistant

# Restart
systemctl --user restart homeassistant

# Enable auto-start
systemctl --user enable homeassistant
```

## Updates

### Update Home Assistant Container

```bash
# SSH to Home Assistant VM
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net

# Check current version
podman exec homeassistant cat /VERSION

# Pull latest stable image
podman pull ghcr.io/home-assistant/home-assistant:stable

# Restart to apply update
systemctl --user restart homeassistant

# Verify new version
podman exec homeassistant cat /VERSION
```

### Update to Specific Version

```bash
# Pull specific version
podman pull ghcr.io/home-assistant/home-assistant:2024.1.0

# Update Quadlet file to pin version
# Edit ~/.config/containers/systemd/homeassistant.container
# Change Image= line

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart homeassistant
```

### Rollback After Failed Update

```bash
# Stop service
systemctl --user stop homeassistant

# List available images
podman images | grep home-assistant

# Tag previous version
podman tag <previous-image-id> ghcr.io/home-assistant/home-assistant:rollback

# Edit Quadlet file to use rollback tag
# Restart
systemctl --user daemon-reload
systemctl --user start homeassistant
```

### Update HACS Integrations

1. Access Web UI: http://home-assistant.discus-moth.ts.net:8123
2. HACS → Updates
3. Install available updates
4. Restart Home Assistant when prompted

## Database Maintenance

### Database Location

```text
~/.config/homeassistant/
├── home-assistant_v2.db      # Main SQLite database
├── home-assistant_v2.db-shm  # SQLite working files
└── home-assistant_v2.db-wal  # Write-ahead log
```

### Check Database Size

```bash
ls -lh ~/.config/homeassistant/home-assistant_v2.db
du -sh ~/.config/homeassistant/
```

### Purge Old Data

**Via Web UI** (Recommended):

1. Settings → System → Repairs
2. Look for database cleanup suggestions

**Via Configuration** (`configuration.yaml`):

```yaml
recorder:
  purge_keep_days: 10
  commit_interval: 1
  exclude:
    domains:
      - automation
      - updater
    entity_globs:
      - sensor.weather_*
```

### Database Optimization

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Backup database first
cp ~/.config/homeassistant/home-assistant_v2.db \
   ~/.config/homeassistant/home-assistant_v2.db.bak

# Vacuum database (reduces size)
sqlite3 ~/.config/homeassistant/home-assistant_v2.db "VACUUM;"

# Reindex
sqlite3 ~/.config/homeassistant/home-assistant_v2.db "REINDEX;"

# Check integrity
sqlite3 ~/.config/homeassistant/home-assistant_v2.db "PRAGMA integrity_check;"

# Start Home Assistant
systemctl --user start homeassistant
```

### Clear Database Locks

If database is locked:

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Remove lock files
rm ~/.config/homeassistant/home-assistant_v2.db-shm
rm ~/.config/homeassistant/home-assistant_v2.db-wal

# Start Home Assistant
systemctl --user start homeassistant
```

## Configuration Management

### Validate Configuration

**Via Web UI**:

1. Developer Tools → YAML
2. Click "Check Configuration"

**Via Command Line**:

```bash
# Exec into container and check config
podman exec homeassistant python -m homeassistant --config /config --script check_config
```

### Reload Configuration

**Via Web UI**:

1. Developer Tools → YAML
2. Click specific reload button (Automations, Scripts, etc.)

**Via API**:

```bash
# Reload all YAML configuration
curl -X POST http://localhost:8123/api/services/homeassistant/reload_all \
  -H "Authorization: Bearer YOUR_LONG_LIVED_TOKEN"
```

### Configuration Backup

```bash
# Manual backup
tar -czf ~/homeassistant-config-$(date +%Y%m%d).tar.gz \
  -C ~/.config homeassistant \
  --exclude='homeassistant/home-assistant_v2.db*' \
  --exclude='homeassistant/.storage/core.restore_state*'

# Include database (larger backup)
tar -czf ~/homeassistant-full-$(date +%Y%m%d).tar.gz \
  -C ~/.config homeassistant
```

## Backup Procedures

### Full Backup

```bash
#!/bin/bash
# Save as ~/backup-homeassistant.sh

BACKUP_DIR="/mnt/data/backups/homeassistant"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop Home Assistant for consistent backup
systemctl --user stop homeassistant

# Create full backup
tar -czf "$BACKUP_DIR/homeassistant-${DATE}.tar.gz" \
  -C ~/.config homeassistant

# Start Home Assistant
systemctl --user start homeassistant

echo "Backup complete: $BACKUP_DIR/homeassistant-${DATE}.tar.gz"
ls -lh "$BACKUP_DIR/homeassistant-${DATE}.tar.gz"
```

### Config-Only Backup (Faster)

```bash
#!/bin/bash
# Backup without database (faster, smaller)

BACKUP_DIR="/mnt/data/backups/homeassistant"
DATE=$(date +%Y%m%d)

tar -czf "$BACKUP_DIR/homeassistant-config-${DATE}.tar.gz" \
  -C ~/.config homeassistant \
  --exclude='homeassistant/home-assistant_v2.db*' \
  --exclude='homeassistant/.storage/core.restore_state*' \
  --exclude='homeassistant/tts/*' \
  --exclude='homeassistant/www/*'
```

### Restore from Backup

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Remove current config
rm -rf ~/.config/homeassistant

# Restore from backup
tar -xzf /mnt/data/backups/homeassistant/homeassistant-YYYYMMDD.tar.gz \
  -C ~/.config/

# Start Home Assistant
systemctl --user start homeassistant
```

### Schedule Automatic Backups

```bash
# Add to crontab
crontab -e

# Daily backup at 3 AM
0 3 * * * /home/ansible/backup-homeassistant.sh >> /var/log/ha-backup.log 2>&1
```

## Integration Maintenance

### Check Integration Status

**Via Web UI**:

1. Settings → Devices & Services
2. Look for integrations with warnings or errors
3. Click integration → Reconfigure if needed

### Reload Integrations

**Via Web UI**:

1. Settings → Devices & Services
2. Click integration → ... menu → Reload

### Remove Stale Integrations

1. Settings → Devices & Services
2. Click integration → Delete

### Update Integration Credentials

If an integration stops working due to credential changes:

1. Settings → Devices & Services
2. Click integration → Reconfigure
3. Enter new credentials

## HACS Maintenance

### Update HACS Itself

```bash
# SSH to Home Assistant VM
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net

# Re-run HACS installer
cd ~/.config/homeassistant
wget -O - https://get.hacs.xyz | bash -

# Restart Home Assistant
systemctl --user restart homeassistant
```

### Clean HACS Cache

```bash
# Remove HACS cache
rm -rf ~/.config/homeassistant/custom_components/hacs/.storage/

# Restart Home Assistant
systemctl --user restart homeassistant
```

### Fix Broken HACS Integration

```bash
# Remove HACS completely
rm -rf ~/.config/homeassistant/custom_components/hacs/

# Restart Home Assistant
systemctl --user restart homeassistant

# Reinstall HACS
cd ~/.config/homeassistant
wget -O - https://get.hacs.xyz | bash -

# Restart again
systemctl --user restart homeassistant
```

## Log Management

### View Logs

```bash
# Systemd journal
journalctl --user -u homeassistant -f

# Container logs
podman logs -f homeassistant

# Application log file
tail -f ~/.config/homeassistant/home-assistant.log
```

### Adjust Log Level

Edit `configuration.yaml`:

```yaml
logger:
  default: warning
  logs:
    homeassistant.core: info
    homeassistant.components.http: warning
    custom_components.hacs: warning
```

Then reload:

1. Developer Tools → YAML → Logger: Reload

### Clean Old Logs

```bash
# Home Assistant rotates logs automatically
# Check log file size
ls -lh ~/.config/homeassistant/home-assistant.log

# Clear systemd journal logs older than 7 days
journalctl --user --vacuum-time=7d
```

## Performance Monitoring

### Resource Usage

```bash
# Container resource usage
podman stats --no-stream homeassistant

# System resources
free -h
df -h /
```

### Slow Dashboard

1. Check browser console for errors
2. Reduce number of entities on dashboard
3. Use `entity_globs` in recorder to exclude frequently updating sensors

### High Database Growth

1. Reduce `purge_keep_days` in recorder config
2. Exclude high-frequency sensors from recording
3. Run database vacuum

## Troubleshooting Common Issues

### Service Won't Start

```bash
# Check status
systemctl --user status homeassistant

# Check logs for errors
journalctl --user -u homeassistant -n 100

# Check configuration
podman exec homeassistant python -m homeassistant --config /config --script check_config

# Check Quadlet file
cat ~/.config/containers/systemd/homeassistant.container
```

### Web UI Not Accessible

```bash
# Check if container is running
podman ps | grep homeassistant

# Check port binding
podman port homeassistant

# Check network mode (should be host)
podman inspect homeassistant --format '{{.HostConfig.NetworkMode}}'

# Check if port is listening
ss -tlnp | grep 8123
```

### Integration Not Working

1. Check Settings → Devices & Services for error messages
2. Try removing and re-adding the integration
3. Check logs for specific integration errors:

   ```bash
   journalctl --user -u homeassistant | grep -i "<integration_name>"
   ```

### Automations Not Running

1. Developer Tools → States → Check automation state
2. Settings → Automations → Check automation is enabled
3. View automation trace for execution details
4. Check conditions are being met

### Database Errors

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Check database integrity
sqlite3 ~/.config/homeassistant/home-assistant_v2.db "PRAGMA integrity_check;"

# If corrupted, remove and let HA rebuild
rm ~/.config/homeassistant/home-assistant_v2.db*

# Start Home Assistant (will create new database)
systemctl --user start homeassistant
```

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Service health check | Daily | Automated via monitoring |
| Check for updates | Weekly | HA Core, HACS, integrations |
| Review error logs | Weekly | Look for recurring issues |
| Database vacuum | Monthly | Reduces database size |
| Full backup | Weekly | Automated via cron |
| Config-only backup | Daily | Smaller, faster |
| Purge old data | Monthly | Adjust recorder settings |
| Review automations | Monthly | Check for failed runs |

## See Also

- [Home Assistant Configuration](../configuration/home-assistant-setup.md)
- [Home Assistant Troubleshooting](../troubleshooting/home-assistant.md)
- [Service Endpoints](../configuration/service-endpoints.md)
