# Download Clients Maintenance

Maintenance procedures for download clients: qBittorrent, SABnzbd, Gluetun (VPN), and Unpackerr.

> **IMPORTANT**: All download clients run as **rootless Podman containers with Quadlet** on the download-clients VM
> (192.168.30.14). Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

| Service | Port | Purpose |
|---------|------|---------|
| Gluetun | N/A | VPN container (PIA) |
| qBittorrent | 8080 | Torrent client |
| SABnzbd | 8081 | Usenet client |
| Unpackerr | N/A | Archive extraction |

## Service Dependencies

```text
Gluetun (VPN) ─┬─> qBittorrent (network namespace)
               └─> SABnzbd (network namespace)

qBittorrent ───┬─> Unpackerr (monitors completed downloads)
SABnzbd ───────┘
```

**Important**: Always start Gluetun first, then other services.

## Routine Maintenance

### Daily Checks

```bash
# SSH to download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Check all services are running
systemctl --user status gluetun qbittorrent sabnzbd unpackerr

# Verify VPN is connected
podman exec gluetun curl -s ifconfig.me
# Should show VPN IP, not home IP

# Check VPN port forwarding
journalctl --user -u gluetun | grep -i "port forward" | tail -5
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /mnt/data
   du -sh /mnt/data/torrents/*
   du -sh /mnt/data/usenet/*
   ```

2. **Clean completed downloads**:
   - qBittorrent: Remove completed torrents (after seeding)
   - SABnzbd: Review history, clear old entries

3. **Check for stuck downloads**:
   - Review qBittorrent queue for stalled torrents
   - Check SABnzbd for failed extractions

### Monthly Maintenance

1. **Update containers**
2. **Review VPN kill switch effectiveness**
3. **Verify backup integrity**
4. **Check indexer connectivity**

## Container Updates

### Update All Services

```bash
# SSH to download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Pull latest images
podman pull ghcr.io/qdm12/gluetun:latest
podman pull docker.io/linuxserver/qbittorrent:latest
podman pull docker.io/linuxserver/sabnzbd:latest
podman pull docker.io/golift/unpackerr:latest

# Restart services in order (VPN first!)
systemctl --user restart gluetun
sleep 30  # Wait for VPN connection
systemctl --user restart qbittorrent sabnzbd unpackerr

# Verify VPN is working
podman exec gluetun curl -s ifconfig.me
```

### Update Single Service

```bash
# Example: Update qBittorrent
podman pull docker.io/linuxserver/qbittorrent:latest
systemctl --user restart qbittorrent

# Verify
journalctl --user -u qbittorrent -n 50
```

## VPN (Gluetun) Maintenance

### Verify VPN Status

```bash
# Check Gluetun logs
journalctl --user -u gluetun -n 100

# Verify VPN IP
podman exec gluetun curl -s ifconfig.me

# Check port forwarding
podman exec gluetun cat /tmp/gluetun/forwarded_port
journalctl --user -u gluetun | grep -i "port forward"
```

### Test Kill Switch

```bash
# The kill switch is automatic in Gluetun
# If VPN disconnects, all traffic is blocked

# Verify by checking qBittorrent can't reach internet without VPN
# (Stop Gluetun temporarily - downloads should fail)
```

### Reconnect VPN

```bash
# Restart Gluetun (will reconnect to VPN)
systemctl --user restart gluetun

# Wait for connection
sleep 30

# Verify
journalctl --user -u gluetun | grep -i "connected"
```

### Change VPN Region

Edit Quadlet file `~/.config/containers/systemd/gluetun.container`:

```ini
Environment=SERVER_REGIONS=US California,US Denver
```

Then restart:

```bash
systemctl --user daemon-reload
systemctl --user restart gluetun qbittorrent sabnzbd
```

## qBittorrent Maintenance

### Check Downloads

1. Access: http://download-clients.discus-moth.ts.net:8080
2. Review active downloads
3. Check for stalled or errored torrents

### Clean Up Completed Torrents

```bash
# Via API - Remove completed torrents (keep files)
# Get list of completed
curl -s "http://localhost:8080/api/v2/torrents/info?filter=completed" \
  -b "SID=your_session_cookie"
```

Or via Web UI:

1. Filter by "Completed"
2. Select all
3. Delete (remove torrent only, keep files)

### Verify Port Forwarding

qBittorrent uses Gluetun's forwarded port:

```bash
# Check port in Gluetun
podman exec gluetun cat /tmp/gluetun/forwarded_port

# Verify in qBittorrent: Options → Connection → Listening Port
# Should match Gluetun's forwarded port
```

### Database Maintenance

```bash
# Stop qBittorrent
systemctl --user stop qbittorrent

# Backup
cp -r ~/.config/qbittorrent ~/.config/qbittorrent.bak

# Check BT_backup folder size (torrent resume data)
du -sh ~/.config/qbittorrent/qBittorrent/BT_backup/

# Start qBittorrent
systemctl --user start qbittorrent
```

## SABnzbd Maintenance

### Check Queue and History

1. Access: http://download-clients.discus-moth.ts.net:8081
2. Review queue for stuck items
3. Check history for failed downloads

### Clean Up History

1. History tab
2. Select old/completed items
3. Delete from history

### Verify API Key

```bash
# API key is in: Config → General → API Key
# Also check: ~/.config/sabnzbd/sabnzbd.ini
grep api_key ~/.config/sabnzbd/sabnzbd.ini
```

### Database Maintenance

```bash
# Stop SABnzbd
systemctl --user stop sabnzbd

# Backup
cp -r ~/.config/sabnzbd ~/.config/sabnzbd.bak

# Check admin directory size
du -sh ~/.config/sabnzbd/admin/

# Start SABnzbd
systemctl --user start sabnzbd
```

## Unpackerr Maintenance

### Check Status

```bash
# View logs
journalctl --user -u unpackerr -f

# Check for extraction errors
journalctl --user -u unpackerr | grep -i error
```

### Verify Configuration

```bash
# Check config file
cat ~/.config/unpackerr/unpackerr.conf

# Verify paths match download clients
grep -E "path|queue" ~/.config/unpackerr/unpackerr.conf
```

### Clear Extraction Cache

Unpackerr tracks extracted files to avoid re-extraction:

```bash
# View extraction history
journalctl --user -u unpackerr | grep -i extract

# If needed, restart to clear in-memory state
systemctl --user restart unpackerr
```

## Backup Procedures

### Backup All Download Client Configs

```bash
#!/bin/bash
# Save as ~/backup-download-clients.sh

BACKUP_DIR="/mnt/data/backups/download-clients"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop services for consistent backup
systemctl --user stop qbittorrent sabnzbd unpackerr

# Backup configs (not download data)
for svc in qbittorrent sabnzbd unpackerr gluetun; do
  if [ -d ~/.config/$svc ]; then
    tar -czf "$BACKUP_DIR/${svc}-${DATE}.tar.gz" -C ~/.config "$svc"
    echo "Backed up $svc"
  fi
done

# Start services
systemctl --user start gluetun
sleep 30
systemctl --user start qbittorrent sabnzbd unpackerr

echo "Backup complete: $BACKUP_DIR"
```

### Restore from Backup

```bash
# Stop services
systemctl --user stop qbittorrent sabnzbd unpackerr gluetun

# Restore config
rm -rf ~/.config/qbittorrent
tar -xzf /mnt/data/backups/download-clients/qbittorrent-YYYYMMDD.tar.gz -C ~/.config/

# Start services
systemctl --user start gluetun
sleep 30
systemctl --user start qbittorrent sabnzbd unpackerr
```

## Disk Space Management

### Check Usage

```bash
# Overall disk usage
df -h /mnt/data

# Download directories
du -sh /mnt/data/torrents/*
du -sh /mnt/data/usenet/*

# Find large incomplete downloads
find /mnt/data/torrents/incomplete -type f -size +5G -exec ls -lh {} \;
```

### Clean Up

```bash
# Remove orphaned incomplete downloads (careful!)
# Only after verifying nothing is actively downloading

# Remove old torrents
find /mnt/data/torrents/complete -type f -mtime +30 -name "*.torrent" -delete

# Remove empty directories
find /mnt/data/torrents -type d -empty -delete
find /mnt/data/usenet -type d -empty -delete
```

## Troubleshooting Common Issues

### VPN Not Connecting

```bash
# Check Gluetun logs
journalctl --user -u gluetun -n 100

# Common issues:
# - Invalid credentials
# - Server region unavailable
# - Network configuration

# Verify credentials in Quadlet file
cat ~/.config/containers/systemd/gluetun.container | grep -i openvpn
```

### qBittorrent Slow Downloads

1. Check VPN port forwarding is working
2. Verify listening port matches Gluetun's forwarded port
3. Check tracker status in qBittorrent
4. Test with a well-seeded public torrent

### SABnzbd Failed Extractions

```bash
# Check logs
journalctl --user -u sabnzbd | grep -i "unpack\|extract"

# Common issues:
# - Disk space full
# - Password-protected archives
# - Incomplete downloads
```

### Unpackerr Not Extracting

```bash
# Check if monitoring correct paths
journalctl --user -u unpackerr | grep -i "watching\|polling"

# Verify Sonarr/Radarr API connection
journalctl --user -u unpackerr | grep -i "sonarr\|radarr"
```

## Performance Monitoring

### Resource Usage

```bash
# Check container resource usage
podman stats --no-stream

# Network throughput
iftop -i eth0

# Disk I/O
iostat -x 1 5
```

### Download Speed Test

```bash
# Test VPN speed (from within Gluetun)
podman exec gluetun curl -s https://speed.cloudflare.com/__down?bytes=100000000 > /dev/null
# Time this command to estimate download speed
```

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Service health check | Daily | Automated via monitoring |
| VPN verification | Daily | Check IP is VPN |
| Disk space check | Weekly | Alert if >80% |
| Clean completed downloads | Weekly | Manual review |
| Container updates | Monthly | Planned window |
| Backup configs | Weekly | Automated |
| Port forwarding check | Weekly | Verify in qBittorrent |

## See Also

- [Download Clients Troubleshooting](../troubleshooting/download-clients.md)
- [VPN/Gluetun Troubleshooting](../troubleshooting/vpn-gluetun.md)
- [Unpackerr Troubleshooting](../troubleshooting/unpackerr.md)
- [VPN Configuration](../configuration/vpn-gluetun.md)
- [Service Endpoints](../configuration/service-endpoints.md)
