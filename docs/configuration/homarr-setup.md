# Homarr Configuration

Homarr is a customizable homepage/dashboard for organizing and accessing all your services in one place. It provides
service status monitoring, integrations with popular applications, and a clean interface for your homelab.

> **IMPORTANT**: Homarr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.30.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: media-services (VMID 401, 192.168.30.13)
- **Port**: 7575
- **Deployment**: Rootless Podman with Quadlet
- **Config Path**: `~/.config/homarr/`
- **Playbook**: [`playbooks/services/media-services.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/media-services.yml)

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:7575
- **Local Network**: http://192.168.30.13:7575

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy all media services including Homarr
./bin/runtime/ansible-run.sh playbooks/services/media-services.yml

# Or deploy Homarr specifically
./bin/runtime/ansible-run.sh playbooks/services/media-services.yml --tags homarr
```

### Quadlet Configuration

Located at `~/.config/containers/systemd/homarr.container`:

```ini
[Unit]
Description=Homarr Dashboard
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/ajnart/homarr:latest
ContainerName=homarr
Network=host
Volume=%h/.config/homarr/configs:/app/data/configs:Z
Volume=%h/.config/homarr/icons:/app/public/icons:Z
Volume=%h/.config/homarr/data:/data:Z
Environment=TZ=America/Denver

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

## Initial Setup

### First-Time Configuration

1. **Access Homarr**: http://media-services.discus-moth.ts.net:7575
2. **Create Account**: Set up admin username and password
3. **Configure Dashboard**: Add tiles for your services

### Adding Service Tiles

1. Click the **Edit** button (pencil icon)
2. Click **Add Tile** (+)
3. Select service type (or generic)
4. Configure:
   - **Name**: Display name for the tile
   - **URL**: Service URL for the link
   - **Icon**: Built-in icon or custom URL
   - **Integration**: Enable for status/API features

## Service Integration URLs

### Same-VM Services (localhost)

Since Homarr uses host networking, services on the same VM are accessed via localhost:

| Service | Internal URL | Port |
|---------|-------------|------|
| Sonarr | `http://localhost:8989` | 8989 |
| Radarr | `http://localhost:7878` | 7878 |
| Prowlarr | `http://localhost:9696` | 9696 |
| Jellyseerr | `http://localhost:5055` | 5055 |
| Bazarr | `http://localhost:6767` | 6767 |
| Huntarr | `http://localhost:9705` | 9705 |
| Byparr | `http://localhost:8191` | 8191 |

### Other-VM Services

For services on different VMs, use Tailscale hostnames or IPs:

| Service | External URL |
|---------|-------------|
| Jellyfin | `http://jellyfin.discus-moth.ts.net:8096` |
| Tdarr | `http://jellyfin.discus-moth.ts.net:8265` |
| qBittorrent | `http://download-clients.discus-moth.ts.net:8080` |
| SABnzbd | `http://download-clients.discus-moth.ts.net:8081` |
| Prometheus | `http://monitoring.discus-moth.ts.net:9090` |
| Grafana | `http://monitoring.discus-moth.ts.net:3000` |
| Uptime Kuma | `http://monitoring.discus-moth.ts.net:3001` |
| AdGuard Home | `http://nas.discus-moth.ts.net` |
| Home Assistant | `http://home-assistant.discus-moth.ts.net:8123` |

## Integrations

Homarr supports deep integrations with many services, providing status information and quick actions.

### Sonarr/Radarr Integration

1. Add tile for Sonarr/Radarr
2. Enable **Integration**
3. Configure:
   - **API URL**: `http://localhost:8989` (Sonarr) or `http://localhost:7878` (Radarr)
   - **API Key**: Copy from Sonarr/Radarr Settings → General → API Key

Features:

- Queue status display
- Missing episodes/movies count
- Recent downloads

### Jellyseerr Integration

1. Add tile for Jellyseerr
2. Enable **Integration**
3. Configure:
   - **API URL**: `http://localhost:5055`
   - **API Key**: Copy from Jellyseerr Settings → General → API Key

Features:

- Pending requests count
- Recent requests display

### qBittorrent Integration

1. Add tile for qBittorrent
2. Enable **Integration**
3. Configure:
   - **API URL**: `http://download-clients.discus-moth.ts.net:8080`
   - **Username**: qBittorrent username
   - **Password**: qBittorrent password

Features:

- Active downloads count
- Download/upload speed

### SABnzbd Integration

1. Add tile for SABnzbd
2. Enable **Integration**
3. Configure:
   - **API URL**: `http://download-clients.discus-moth.ts.net:8081`
   - **API Key**: Copy from SABnzbd Config → General → API Key

Features:

- Queue status
- Download speed

### Jellyfin Integration

1. Add tile for Jellyfin
2. Enable **Integration**
3. Configure:
   - **API URL**: `http://jellyfin.discus-moth.ts.net:8096`
   - **API Key**: Create in Jellyfin Dashboard → API Keys

Features:

- Active sessions count
- Library statistics

## Customization

### Layout Configuration

1. Click **Edit** mode
2. Drag tiles to rearrange
3. Resize tiles by dragging corners
4. Create sections with headers

### Themes and Appearance

1. Settings (gear icon) → Appearance
2. Options:
   - **Color scheme**: Light/Dark/System
   - **Primary color**: Accent color
   - **Background**: Solid color or image

### Custom Icons

1. Upload icons to `~/.config/homarr/icons/`
2. Reference in tile configuration: `/icons/filename.png`
3. Or use external URLs for icons

### Categories/Sections

Organize tiles into logical groups:

1. Add a **Section** tile
2. Name it (e.g., "Media", "Downloads", "Monitoring")
3. Drag service tiles into sections

## Configuration Files

### Directory Structure

```text
~/.config/homarr/
├── configs/           # Board configurations
│   └── default.json   # Main dashboard config
├── icons/             # Custom icons
└── data/              # Application data
```

### Backup Configuration

```bash
# Create backup
tar -czf ~/homarr-backup-$(date +%Y%m%d).tar.gz -C ~/.config homarr

# Copy to backup location
cp ~/homarr-backup-*.tar.gz /mnt/data/backups/
```

### Restore Configuration

```bash
# Stop service
systemctl --user stop homarr

# Restore backup
tar -xzf ~/homarr-backup-YYYYMMDD.tar.gz -C ~/.config/

# Start service
systemctl --user start homarr
```

## Recommended Dashboard Layout

### Example Organization

```text
┌─────────────────────────────────────────────────────────────┐
│                    📺 Media Management                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Sonarr  │  │  Radarr  │  │ Prowlarr │  │ Bazarr   │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
├─────────────────────────────────────────────────────────────┤
│                    📥 Downloads                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  qBittorrent │  │   SABnzbd    │  │  Jellyseerr  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    🎬 Media Servers                         │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   Jellyfin   │  │    Tdarr     │                        │
│  └──────────────┘  └──────────────┘                        │
├─────────────────────────────────────────────────────────────┤
│                    📊 Monitoring                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Grafana  │  │ Uptime K │  │ Proxmox  │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Service Management

### Check Status

```bash
systemctl --user status homarr
```

### View Logs

```bash
journalctl --user -u homarr -f
```

### Restart Service

```bash
systemctl --user restart homarr
```

### Update Homarr

```bash
# Pull latest image
podman pull ghcr.io/ajnart/homarr:latest

# Restart service
systemctl --user restart homarr
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Can't access web UI | Check service: `systemctl --user status homarr` |
| Integration not working | Verify API URL uses `localhost` for same-VM services |
| Settings not saving | Check permissions on `~/.config/homarr/` |
| Icons not loading | Verify icon URLs are accessible from Homarr |
| Slow dashboard | Reduce number of tiles with active integrations |

## See Also

- [Homarr Troubleshooting](../troubleshooting/homarr.md)
- [Service Endpoints](service-endpoints.md)
- [Media Services Workflow](../reference/media-services-workflow.md)
