# Backup and Recovery Procedures

Comprehensive backup strategy and disaster recovery procedures for the Jellybuntu infrastructure.

## Backup Philosophy

**3-2-1 Rule**:

- **3** copies of data
- **2** different storage media
- **1** offsite/cloud copy

**Critical vs. Replaceable**:

- **Critical**: Configuration files, databases, settings (small, must backup)
- **Replaceable**: Media files (large, can re-download if needed)
- **Focus**: Backup configurations that take hours to recreate, not TB of media

## What to Backup

### Critical Data (Must Backup)

| Component | Data | Location | Size | Frequency |
|-----------|------|----------|------|-----------|
| **Sonarr** | Database, config | `/opt/media-stack/sonarr` | ~50MB | Weekly |
| **Radarr** | Database, config | `/opt/media-stack/radarr` | ~50MB | Weekly |
| **Prowlarr** | Database, config | `/opt/media-stack/prowlarr` | ~10MB | Weekly |
| **Jellyseerr** | Database, config | `/opt/media-stack/jellyseer/config` | ~20MB | Weekly |
| **Bazarr** | Database, config | `/opt/media-stack/bazarr` | ~30MB | Weekly |
| **qBittorrent** | Settings, categories | `/opt/media-stack/qbittorrent/config` | ~1MB | Weekly |
| **SABnzbd** | Config file | `/opt/media-stack/sabnzbd/config` | ~1MB | Weekly |
| **Jellyfin** | Database, metadata | `/opt/media-stack/jellyfin` | ~500MB | Weekly |
| **Homarr** | Config, database | `/opt/media-services/homarr` | ~5MB | Monthly |
| **Recyclarr** | Config | `/opt/media-stack/recyclarr/config` | ~1KB | Monthly |
| **Gluetun** | Config (minimal) | `/opt/media-stack/gluetun` | ~1KB | Monthly |
| **Ansible** | Playbooks, inventory, vault | Project directory | ~10MB | After changes |
| **Quadlet configs** | Container files | `~/.config/containers/systemd/*.container` | ~50KB | After changes |

**Total Critical Data**: ~700MB (easily manageable)

### Replaceable Data (Optional Backup)

- **Media files** (`/mnt/data/media/*`): Can re-download
- **Download cache** (`/mnt/data/torrents/*`, `/mnt/data/usenet/*`): Temporary
- **NAS data** (`/nas-storage/*`): If backed up separately via Btrfs snapshots

## Backup Strategies

### Strategy 1: Manual Backups (Simple, Immediate)

Quick manual backup of all critical configs:

```bash
#!/bin/bash
# Manual backup script
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/mnt/data/backups/manual-$BACKUP_DATE"

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# Backup media-services VM (Sonarr, Radarr, etc.)
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo tar -czf /tmp/media-services-backup.tar.gz /opt/media-stack"
scp -i ~/.ssh/ansible_homelab \
  ansible@media-services.discus-moth.ts.net:/tmp/media-services-backup.tar.gz \
  "$BACKUP_DIR/"

# Backup download-clients VM (qBittorrent, SABnzbd)
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "sudo tar -czf /tmp/download-clients-backup.tar.gz /opt/media-stack"
scp -i ~/.ssh/ansible_homelab \
  ansible@download-clients.discus-moth.ts.net:/tmp/download-clients-backup.tar.gz \
  "$BACKUP_DIR/"

# Backup Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "sudo tar -czf /tmp/jellyfin-backup.tar.gz /opt/media-stack/jellyfin"
scp -i ~/.ssh/ansible_homelab \
  ansible@jellyfin.discus-moth.ts.net:/tmp/jellyfin-backup.tar.gz \
  "$BACKUP_DIR/"

# Backup Ansible project
tar -czf "$BACKUP_DIR/ansible-project.tar.gz" \
  -C ~/coding/mirrors jellybuntu \
  --exclude=".git" \
  --exclude="*.retry"

echo "Backup complete: $BACKUP_DIR"
echo "Size: $(du -sh $BACKUP_DIR | cut -f1)"
```

Save as `/usr/local/bin/jellybuntu-backup.sh` and run weekly.

### Strategy 2: Per-Service Backup Scripts

Individual VM backup scripts for granular control:

**Media Services VM**:

```bash
# Run on media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Stop services (optional, for consistency)
cd /opt/media-stack
docker compose stop

# Backup
sudo tar -czf /tmp/media-services-$(date +%Y%m%d).tar.gz \
  /opt/media-stack \
  --exclude='*/logs/*' \
  --exclude='*/cache/*'

# Restart services
docker compose start

# Copy to NAS
sudo mv /tmp/media-services-*.tar.gz /mnt/data/backups/
```

**Download Clients VM**:

```bash
# Similar process for download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

cd /opt/media-stack
docker compose stop

sudo tar -czf /tmp/download-clients-$(date +%Y%m%d).tar.gz \
  /opt/media-stack \
  --exclude='*/logs/*'

docker compose start
sudo mv /tmp/download-clients-*.tar.gz /mnt/data/backups/
```

**Jellyfin VM**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

docker stop jellyfin

sudo tar -czf /tmp/jellyfin-$(date +%Y%m%d).tar.gz \
  /opt/media-stack/jellyfin \
  --exclude='*/transcodes/*' \
  --exclude='*/cache/*'

docker start jellyfin
sudo mv /tmp/jellyfin-*.tar.gz /mnt/data/backups/
```

### Strategy 3: Automated Backups with Cron

Set up automated weekly backups:

```bash
# Edit crontab on control machine (your workstation)
crontab -e

# Add weekly backup (Sundays at 3 AM)
0 3 * * 0 /usr/local/bin/jellybuntu-backup.sh >> /var/log/jellybuntu-backup.log 2>&1

# Or use systemd timer (see Strategy 4)
```

### Strategy 4: Systemd Timer (Recommended)

More reliable than cron for server backups:

```bash
# Create backup service
sudo nano /etc/systemd/system/jellybuntu-backup.service

# Add content:
[Unit]
Description=Jellybuntu Backup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/jellybuntu-backup.sh
User=root
StandardOutput=journal
StandardError=journal
```

```bash
# Create timer
sudo nano /etc/systemd/system/jellybuntu-backup.timer

# Add content:
[Unit]
Description=Weekly Jellybuntu Backup
Requires=jellybuntu-backup.service

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now jellybuntu-backup.timer

# Check status
sudo systemctl list-timers jellybuntu-backup.timer
sudo systemctl status jellybuntu-backup.service
```

### Strategy 5: Btrfs Snapshots (NAS)

Leverage Btrfs filesystem snapshots on NAS VM:

```bash
# SSH to NAS VM
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Create snapshot of /nas-storage
sudo btrfs subvolume snapshot \
  /nas-storage \
  /nas-storage/.snapshots/backup-$(date +%Y%m%d)

# List snapshots
sudo btrfs subvolume list /nas-storage

# Automate with cron
sudo crontab -e
# Daily snapshot at 2 AM
0 2 * * * btrfs subvolume snapshot /nas-storage /nas-storage/.snapshots/backup-$(date +\%Y\%m\%d)
```

Snapshot retention:

```bash
# Keep only last 7 daily snapshots
sudo find /nas-storage/.snapshots -name "backup-*" -mtime +7 -exec btrfs subvolume delete {} \;
```

## Backup Storage Locations

### Primary Backup Location (NAS)

Store backups on NAS at `/mnt/data/backups`:

```bash
# Create backup directory structure
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
sudo mkdir -p /nas-storage/backups/{media-services,download-clients,jellyfin,ansible}
sudo chown -R ansible:ansible /nas-storage/backups
```

### Secondary Backup Location (External Drive)

Periodically copy backups to external USB drive:

```bash
# Mount external drive
sudo mkdir -p /mnt/backup-drive
sudo mount /dev/sdX1 /mnt/backup-drive

# Copy backups
sudo rsync -av --progress \
  /mnt/data/backups/ \
  /mnt/backup-drive/jellybuntu-backups/

# Unmount when done
sudo umount /mnt/backup-drive
```

### Tertiary Backup Location (Cloud - Optional)

Use rclone to sync to cloud storage (B2, S3, Google Drive):

```bash
# Install rclone
sudo apt install rclone

# Configure remote (interactive)
rclone config

# Sync backups to cloud
rclone sync /mnt/data/backups/ remote:jellybuntu-backups \
  --exclude "*.tmp" \
  --progress

# Automate with cron
0 5 * * 1 rclone sync /mnt/data/backups/ remote:jellybuntu-backups >> /var/log/rclone-backup.log 2>&1
```

## Recovery Procedures

### Full Infrastructure Recovery

Complete disaster recovery from scratch:

**Prerequisites**:

- Fresh Proxmox installation
- Backup files accessible
- SSH keys available
- Vault password known

**Steps**:

1. **Restore Ansible Project**:

   ```bash
   # Extract Ansible backup
   tar -xzf ansible-project.tar.gz -C ~/coding/mirrors/

   # Verify files
   cd ~/coding/mirrors/jellybuntu
   ls -la
   ```

2. **Run Initial Setup**:

   ```bash
   # Bootstrap infrastructure
   ./setup.sh

   # Deploy Phase 1-2 (VMs + Networking)
   ./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
   ./bin/runtime/ansible-run.sh playbooks/main-phase2-bootstrap.yml
   ```

3. **Stop Services Before Restore**:

   ```bash
   # Stop all containers on each VM
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "cd /opt/media-stack && docker compose down"

   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "cd /opt/media-stack && docker compose down"

   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "docker stop jellyfin"
   ```

4. **Restore Service Data**:

   ```bash
   # Media services
   scp -i ~/.ssh/ansible_homelab \
     media-services-backup.tar.gz \
     ansible@media-services.discus-moth.ts.net:/tmp/
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "sudo tar -xzf /tmp/media-services-backup.tar.gz -C /"

   # Download clients
   scp -i ~/.ssh/ansible_homelab \
     download-clients-backup.tar.gz \
     ansible@download-clients.discus-moth.ts.net:/tmp/
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "sudo tar -xzf /tmp/download-clients-backup.tar.gz -C /"

   # Jellyfin
   scp -i ~/.ssh/ansible_homelab \
     jellyfin-backup.tar.gz \
     ansible@jellyfin.discus-moth.ts.net:/tmp/
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo tar -xzf /tmp/jellyfin-backup.tar.gz -C /"
   ```

5. **Fix Permissions**:

   ```bash
   # Media services
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "sudo chown -R 1000:1000 /opt/media-stack"

   # Download clients
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "sudo chown -R 1000:1000 /opt/media-stack"

   # Jellyfin
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo chown -R 1000:1000 /opt/media-stack/jellyfin"
   ```

6. **Start Services**:

   ```bash
   # Media services
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "cd /opt/media-stack && docker compose up -d"

   # Download clients
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "cd /opt/media-stack && docker compose up -d"

   # Jellyfin
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "docker start jellyfin"
   ```

7. **Verify Services**:
   - Check all web UIs accessible
   - Verify Sonarr/Radarr databases intact
   - Test Jellyfin library access
   - Confirm download clients working

### Single Service Recovery

Restore individual service without full rebuild:

**Example: Sonarr Recovery**:

```bash
# Stop Sonarr
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker stop sonarr"

# Backup current (corrupted) data
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo mv /opt/media-stack/sonarr /opt/media-stack/sonarr.corrupted"

# Extract backup
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo tar -xzf /mnt/data/backups/media-services-20241028.tar.gz \
    -C / opt/media-stack/sonarr"

# Fix permissions
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo chown -R 1000:1000 /opt/media-stack/sonarr"

# Start Sonarr
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker start sonarr"

# Verify
curl http://media-services.discus-moth.ts.net:8989
```

### Database Recovery (Corrupted SQLite)

If service database corrupts:

```bash
# Example: Radarr database recovery
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Stop service
docker stop radarr

# Backup corrupted DB
sudo cp /opt/media-stack/radarr/radarr.db /tmp/radarr.db.corrupted

# Attempt repair
sudo apt install sqlite3
sqlite3 /opt/media-stack/radarr/radarr.db ".recover" > /tmp/radarr-recovered.sql

# If repair succeeds, rebuild DB
sudo rm /opt/media-stack/radarr/radarr.db
sqlite3 /opt/media-stack/radarr/radarr.db < /tmp/radarr-recovered.sql

# If repair fails, restore from backup
sudo rm /opt/media-stack/radarr/radarr.db
sudo tar -xzf /mnt/data/backups/latest-backup.tar.gz \
  -C / opt/media-stack/radarr/radarr.db

# Start service
docker start radarr
```

## Testing Backups

**Critical**: Regularly test backup restoration to ensure backups are valid.

### Backup Validation Script

```bash
#!/bin/bash
# Test backup integrity
BACKUP_FILE="/mnt/data/backups/media-services-latest.tar.gz"

# Test 1: Archive integrity
echo "Testing archive integrity..."
tar -tzf "$BACKUP_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Archive is valid"
else
  echo "✗ Archive is corrupted!"
  exit 1
fi

# Test 2: Extract to temp location
echo "Testing extraction..."
TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "✓ Extraction successful"
else
  echo "✗ Extraction failed!"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Test 3: Verify key files exist
echo "Verifying critical files..."
if [ -f "$TEMP_DIR/opt/media-stack/sonarr/sonarr.db" ]; then
  echo "✓ Sonarr database found"
else
  echo "✗ Sonarr database missing!"
fi

# Cleanup
rm -rf "$TEMP_DIR"
echo "Backup validation complete"
```

### Test Recovery in VM (Best Practice)

1. Create test Proxmox VM
2. Restore backup to test VM
3. Verify services start and data intact
4. Document any issues
5. Destroy test VM

## Backup Retention Policy

Recommended retention:

- **Daily backups**: Keep 7 days
- **Weekly backups**: Keep 4 weeks
- **Monthly backups**: Keep 12 months

Automated cleanup:

```bash
# Delete backups older than 7 days (daily)
find /mnt/data/backups/daily -name "*.tar.gz" -mtime +7 -delete

# Delete backups older than 28 days (weekly)
find /mnt/data/backups/weekly -name "*.tar.gz" -mtime +28 -delete

# Delete backups older than 365 days (monthly)
find /mnt/data/backups/monthly -name "*.tar.gz" -mtime +365 -delete
```

## Emergency Contacts & Information

Document critical info for disaster recovery:

**Passwords/Keys**:

- Ansible vault password (keep offline/secure)
- Proxmox root password
- VPN credentials
- Tailscale auth key

**Service Credentials**:

- Document where API keys stored (SOPS-encrypted secrets file)
- Database passwords (usually none for SQLite)
- Download client credentials

**External Dependencies**:

- Usenet provider account info
- VPN provider account info
- DNS/domain registrar (if applicable)

## See Also

- [NAS Setup Reference](../reference/nas-setup.md)
- [Btrfs Optimization Guide](../reference/btrfs-optimization.md)
- [Common Issues](../troubleshooting/common-issues.md)
- [Service Endpoints](../configuration/service-endpoints.md)
