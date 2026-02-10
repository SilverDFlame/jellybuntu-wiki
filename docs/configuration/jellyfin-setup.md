# Jellyfin Configuration

Jellyfin is an open-source media server that organizes and streams your media collection. It provides a clean
interface for managing movies, TV shows, music, and photos.

> **IMPORTANT**: Jellyfin runs as a **native systemd service** on the Jellyfin VM (192.168.0.12).
> Use `sudo systemctl` commands, NOT `systemctl --user`. Jellyfin is NOT containerized.

## Overview

- **VM**: jellyfin (VMID 400, 192.168.0.12)
- **Ports**: 8096 (HTTP), 8920 (HTTPS), 7359 (Discovery)
- **Deployment**: Native systemd service (not containerized)
- **Config Path**: `/etc/jellyfin/` and `/var/lib/jellyfin/`
- **Media Path**: `/mnt/data/media/` (NFS mount)
- **Playbook**: [`playbooks/services/jellyfin.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin.yml)

## Access

- **Tailscale**: http://jellyfin.discus-moth.ts.net:8096
- **Local Network**: http://192.168.0.12:8096

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy Jellyfin
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml
```

The playbook:

1. Installs Jellyfin from official repository
2. Configures hardware transcoding (Intel QSV if available)
3. Sets up NFS mount for media storage
4. Configures firewall rules
5. Enables and starts the service

## Initial Setup

### First-Time Configuration

1. **Access Jellyfin**: http://jellyfin.discus-moth.ts.net:8096
2. **Select Language**: Choose preferred language
3. **Create Admin Account**: Set username and password
4. **Add Media Libraries**:
   - Movies: `/mnt/data/media/movies`
   - TV Shows: `/mnt/data/media/tv`
   - Music: `/mnt/data/media/music` (optional)
5. **Configure Metadata**: Select preferred metadata providers
6. **Complete Setup**: Finish the wizard

## Automated API Configuration

After completing the initial setup wizard and creating an admin account, the
[`jellyfin_config`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin_config)
Ansible role can automate the remaining Jellyfin configuration via the API.

### Prerequisites

- Manual initial setup **must** be completed first (admin account + wizard)
- Jellyfin must be running and accessible

### What It Configures

- **System settings**: Server name, language, encoding preferences
- **NVENC hardware encoding**: GPU-accelerated transcoding via GTX 1080
- **Media libraries**: Movies, TV Shows, and Anime with metadata fetchers
  (TMDb, AniDB, OMDb)
- **Scheduled tasks**: Optimize task timing for off-peak hours
- **Plugins**: AniDB, Intro Skipper, Chapter Segments Provider

### Running the Configuration

```bash
./bin/runtime/ansible-run.sh playbooks/services/jellyfin-config.yml
```

> **Note**: This playbook is idempotent and safe to re-run. It will skip
> configuration that already matches the desired state.

### Version Pinning

Jellyfin is pinned to the **10.10.x** release series via the
`jellyfin_version_pin` variable. Version 10.11.x has known performance
regressions tracked in
[Issue #58](https://github.com/SilverDFlame/jellybuntu/issues/58).

### Reference

- **Role**: [`roles/jellyfin_config/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin_config)
- **Playbook**: [`playbooks/services/jellyfin-config.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin-config.yml)

### Library Configuration

#### Movies Library

1. Dashboard → Libraries → Add Media Library
2. Content type: **Movies**
3. Display name: **Movies**
4. Folders: `/mnt/data/media/movies`
5. Metadata settings:
   - Language: English
   - Country: United States
   - Enable **TheMovieDb** for metadata

#### TV Shows Library

1. Dashboard → Libraries → Add Media Library
2. Content type: **Shows**
3. Display name: **TV Shows**
4. Folders: `/mnt/data/media/tv`
5. Metadata settings:
   - Language: English
   - Enable **TheMovieDb** and **TheTVDB**

## Hardware Transcoding

### Intel Quick Sync Video (QSV)

If the VM has Intel GPU passthrough configured:

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **Intel QuickSync (QSV)**
3. Enable hardware decoding for:
   - H264
   - HEVC
   - MPEG2
   - VC1
   - VP8/VP9
4. Enable **hardware encoding**
5. Enable **tone mapping** for HDR content

### Verify Hardware Transcoding

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Check for Intel GPU
ls -la /dev/dri/

# Check Jellyfin can access GPU
sudo -u jellyfin ls -la /dev/dri/

# Check transcoding logs during playback
sudo journalctl -u jellyfin -f | grep -i transcode
```

### Software Transcoding

If hardware acceleration is unavailable:

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **None**
3. Adjust thread count based on CPU cores
4. Consider limiting concurrent transcodes

## User Management

### Creating Users

1. Dashboard → Users → Add User
2. Configure:
   - Username
   - Password (or no password for local users)
   - Library access
   - Playback permissions

### User Permissions

| Permission | Recommended For |
|------------|-----------------|
| Administrator | Admin only |
| Allow media playback | All users |
| Allow media deletion | Admin only |
| Allow remote connections | Tailscale users |
| Allow transcoding | All users (with limits) |

### Integration with Jellyseerr

Jellyfin users automatically sync with Jellyseerr for media requests:

1. Create users in Jellyfin first
2. Users can log into Jellyseerr with Jellyfin credentials
3. Request permissions managed in Jellyseerr

## Network Configuration

### Remote Access

For access via Tailscale (recommended):

1. Dashboard → Networking
2. Known proxies: Leave empty
3. Public HTTPS port: 8920 (optional)
4. Allow remote connections: **Enabled**
5. LAN networks: `192.168.0.0/24,100.64.0.0/10` (local + Tailscale)

### DLNA/UPnP (Optional)

For local network discovery:

1. Dashboard → DLNA
2. Enable DLNA server: **Yes** (if desired)
3. DLNA client discovery: Automatic

## Playback Settings

### Streaming Quality

Dashboard → Playback → Streaming:

| Setting | Recommended Value |
|---------|------------------|
| Maximum streaming bitrate | 120 Mbps (local) |
| Internet streaming bitrate | 20 Mbps |
| Direct play | Preferred |
| Allow subtitle extraction | Enabled |

### Subtitle Configuration

Dashboard → Playback → Subtitles:

1. Preferred subtitle language: English
2. Subtitle mode: Default (or Always Show)
3. Prefer forced subtitles: Yes
4. Burn in subtitles when transcoding: Only when necessary

## Integration with Arr Stack

### Connecting to Sonarr/Radarr

Jellyfin doesn't directly connect to Sonarr/Radarr. Instead:

1. **Sonarr/Radarr** manage downloads and organization
2. **Files are saved** to NFS mount (`/mnt/data/media/`)
3. **Jellyfin scans** the library to detect new content

### Automatic Library Refresh

Configure library monitoring:

1. Dashboard → Libraries → (Select Library) → Edit
2. Enable: **Enable real time monitoring**
3. Scan interval: 12 hours (or manual)

Or trigger via API from Sonarr/Radarr webhooks:

```bash
# Trigger library scan via API
curl -X POST "http://localhost:8096/Library/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"
```

### Jellyseerr Integration

1. In Jellyseerr Settings → Jellyfin:
   - Hostname: `http://192.168.0.12:8096`
   - API Key: (Generate in Jellyfin Dashboard → API Keys)
2. Enable library sync
3. Import users from Jellyfin

## API Configuration

### Generate API Key

1. Dashboard → API Keys
2. Click **+** to create new key
3. Name it (e.g., "Jellyseerr", "Scripts")
4. Copy the key securely

### Common API Endpoints

```bash
# Base URL
http://192.168.0.12:8096

# Get system info
curl "http://localhost:8096/System/Info" \
  -H "X-Emby-Token: API_KEY"

# Trigger library scan
curl -X POST "http://localhost:8096/Library/Refresh" \
  -H "X-Emby-Token: API_KEY"

# Get active sessions
curl "http://localhost:8096/Sessions" \
  -H "X-Emby-Token: API_KEY"
```

## Plugin Management

### Installing Plugins

1. Dashboard → Plugins → Catalog
2. Browse available plugins
3. Click to install
4. Restart Jellyfin to activate

### Recommended Plugins

| Plugin | Purpose |
|--------|---------|
| Open Subtitles | Automatic subtitle downloads |
| Playback Reporting | Track viewing statistics |
| Trakt | Sync watch history with Trakt.tv |
| TMDb Box Sets | Automatic collection creation |

## Service Management

### Check Status

```bash
# Native systemd service (requires sudo)
sudo systemctl status jellyfin
```

### View Logs

```bash
# Follow logs in real-time
sudo journalctl -u jellyfin -f

# View recent logs
sudo journalctl -u jellyfin -n 100

# Search for errors
sudo journalctl -u jellyfin | grep -i error
```

### Restart Service

```bash
sudo systemctl restart jellyfin
```

### Update Jellyfin

```bash
# Update via package manager
sudo apt update
sudo apt upgrade jellyfin

# Or via Ansible
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml
```

## Backup and Restore

### Backup Configuration

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Backup config and data
sudo tar -czf ~/jellyfin-backup-$(date +%Y%m%d).tar.gz \
  /etc/jellyfin \
  /var/lib/jellyfin

# Copy to safe location
cp ~/jellyfin-backup-*.tar.gz /mnt/data/backups/

# Restart Jellyfin
sudo systemctl start jellyfin
```

### Restore Configuration

```bash
# Stop Jellyfin
sudo systemctl stop jellyfin

# Restore from backup
sudo tar -xzf ~/jellyfin-backup-YYYYMMDD.tar.gz -C /

# Fix permissions
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
sudo chown -R jellyfin:jellyfin /etc/jellyfin

# Start Jellyfin
sudo systemctl start jellyfin
```

## Performance Tuning

### Memory Configuration

Edit `/etc/jellyfin/encoding.xml` for transcoding memory limits.

### Concurrent Streams

Dashboard → Playback → Transcoding:

- Limit concurrent transcodes based on CPU/GPU capability
- Recommended: 2-4 for software, 4-8 for hardware transcoding

### Database Optimization

```bash
# Vacuum the database (run during low usage)
sudo systemctl stop jellyfin
sudo sqlite3 /var/lib/jellyfin/data/library.db "VACUUM;"
sudo systemctl start jellyfin
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Can't access web UI | Check service: `sudo systemctl status jellyfin` |
| Transcoding failing | Check GPU permissions and logs |
| Library not updating | Trigger manual scan or check NFS mount |
| Slow playback | Check network and transcoding settings |
| Users can't log in | Verify user accounts in Dashboard → Users |

## See Also

- [Jellyfin Troubleshooting](../troubleshooting/jellyfin.md)
- [Tdarr Configuration](tdarr-setup.md) - Automatic transcoding
- [Jellyseerr Setup](jellyseerr-setup.md) - Media requests
- [GPU Passthrough](gpu-passthrough.md) - Hardware acceleration
- [Service Endpoints](service-endpoints.md)
