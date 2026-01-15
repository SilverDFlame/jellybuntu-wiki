# Homepage Dashboard Setup Guide

Homepage is a modern, fully static, fast, secure application dashboard with integrations for over 100 services. It
provides a unified view of all media services with real-time statistics.

## Overview

- **VM**: media-services (192.168.0.13)
- **Port**: 3000
- **Container**: homepage
- **Config Path**: `/opt/media-stack/homepage`
- **Image**: ghcr.io/gethomepage/homepage:v0.10.11
- **Network Mode**: host (for API access to local services)

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:3000
- **Local Network**: http://192.168.0.13:3000

## Architecture

Homepage uses host networking to access APIs of services running on the same VM without Docker network complexity. This
simplifies widget configuration since all services are accessible via `localhost`.

## Configuration Files

Homepage is configured via YAML files in `/opt/media-stack/homepage`:

| File | Purpose |
|------|---------|
| `settings.yaml` | General settings (theme, title, layout) |
| `services.yaml` | Service definitions and widgets |
| `widgets.yaml` | Dashboard widgets (optional) |
| `bookmarks.yaml` | Quick links bookmarks (optional) |
| `docker.yaml` | Docker integration settings (optional) |

## Initial Access

Homepage works out of the box with the deployed configuration. Simply navigate to:

```
http://media-services.discus-moth.ts.net:3000
```

You'll see a dashboard organized into sections:

- **Media Management**: Sonarr, Radarr, Prowlarr, Bazarr, Huntarr, Jellyseerr
- **Download Clients**: qBittorrent, SABnzbd
- **Media Server**: Jellyfin
- **Management**: Portainer, FlareSolverr

## Configuration Details

### Settings Configuration

File: `/opt/media-stack/homepage/settings.yaml`

```yaml
title: Media Stack Dashboard
description: Jellybuntu Media Server - Automated Media Management
theme: dark
color: slate
headerStyle: clean

# Layout per section

layout:
  Media Management:
    style: row
    columns: 4
  Download Clients:
    style: row
    columns: 2
  Media Server:
    style: row
    columns: 1
  Management:
    style: row
    columns: 2

# Quick launch search

quicklaunch:
  searchDescriptions: true
  hideInternetSearch: true

# Show container stats

showStats: true
statusStyle: dot
```

**Customizable Options**:

- **title**: Dashboard title
- **theme**: light, dark (default: dark)
- **color**: slate, gray, zinc, neutral, stone (default: slate)
- **headerStyle**: clean, boxed, underlined
- **layout**: Columns and style per section
- **quicklaunch**: Enable/disable search
- **showStats**: Show service status dots
- **target**: \_self (same tab) or \_blank (new tab)

### Services Configuration

File: `/opt/media-stack/homepage/services.yaml`

Services are organized into groups with optional widgets showing live data.

**Example Service with Widget**:
```yaml
- Media Management:
    - Sonarr:
        icon: sonarr.png
        href: http://media-services.discus-moth.ts.net:8989
        description: TV Show management and automation
        widget:
          type: sonarr
          url: http://localhost:8989
          key: YOUR_API_KEY
          fields: ["wanted", "queued", "series"]
          enableQueue: true
```

**Widget Configuration**:

- **type**: Service type (sonarr, radarr, jellyfin, etc.)
- **url**: API URL (use `localhost` for same-VM services)
- **key**: API key from service settings
- **fields**: Data points to display
- **enableQueue**: Show queue info (for *arr apps)

### API Keys Required

Homepage widgets need API keys from each service:

| Service | API Key Location |
|---------|------------------|
| Sonarr | Settings → General → Security → API Key |
| Radarr | Settings → General → Security → API Key |
| Prowlarr | Settings → General → Security → API Key |
| Bazarr | Settings → General → Security → API Key |
| SABnzbd | Config → General → Security → API Key |
| Jellyfin | Dashboard → Advanced → API Keys → New Key |

qBittorrent uses username/password (default: admin / your configured password).

## Customizing Homepage

### Add a New Service

1. **SSH to media-services VM**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net
   ```

2. **Edit services.yaml**:

   ```bash
   cd /opt/media-stack/homepage
   sudo nano services.yaml
   ```

3. **Add service to appropriate group**:

   ```yaml
   - Media Management:
       - New Service:
           icon: service-icon.png
           href: http://service-url:port
           description: Service description
           widget:
             type: service-type
             url: http://localhost:port
             key: API_KEY
   ```

4. **Restart Homepage**:

   ```bash
   docker restart homepage
   ```

5. **Verify**: Refresh dashboard in browser

### Change Theme

1. Edit `settings.yaml`:

   ```yaml
   theme: light  # or dark
   color: gray   # slate, gray, zinc, neutral, stone
   ```

2. Restart Homepage:

   ```bash
   docker restart homepage
   ```

### Modify Layout

1. Edit `settings.yaml` layout section:

   ```yaml
   layout:
     Media Management:
       style: row    # or column
       columns: 4    # services per row
   ```

2. Restart Homepage

### Add Custom Bookmarks

1. Create/edit `bookmarks.yaml`:

   ```yaml
   - Media:
       - Jellyfin:
           - href: http://jellyfin.discus-moth.ts.net:8096
             description: Media Server
       - Jellyseerr:
           - href: http://media-services.discus-moth.ts.net:5055
             description: Request Content

   - Management:
       - Proxmox:
           - href: https://jellybuntu.discus-moth.ts.net:8006
             description: Hypervisor
   ```

2. Restart Homepage

### Add Custom Widgets

Homepage supports information widgets (time, weather, search, etc.):

1. Create/edit `widgets.yaml`:

   ```yaml
   - datetime:
       text_size: xl
       format:
         timeStyle: short
         dateStyle: short

   - search:
       provider: google
       target: _blank
   ```

2. Restart Homepage

## Widget Types and Configuration

### Sonarr/Radarr Widget

```yaml
widget:
  type: sonarr  # or radarr
  url: http://localhost:8989
  key: API_KEY
  fields: ["wanted", "queued", "series"]
  enableQueue: true
```

**Fields**: wanted, missing, queued, series (Sonarr), movies (Radarr)

### Prowlarr Widget

```yaml
widget:
  type: prowlarr
  url: http://localhost:9696
  key: API_KEY
  fields: ["numberOfGrabs", "numberOfQueries"]
```

### Bazarr Widget

```yaml
widget:
  type: bazarr
  url: http://localhost:6767
  key: API_KEY
```

Shows subtitle download stats automatically.

### qBittorrent Widget

```yaml
widget:
  type: qbittorrent
  url: http://download-clients.discus-moth.ts.net:8080
  username: admin
  password: YOUR_PASSWORD
  fields: ["leech", "download", "seed", "upload"]
```

**Fields**: leech (downloading), download (speed), seed (seeding), upload (speed)

### SABnzbd Widget

```yaml
widget:
  type: sabnzbd
  url: http://download-clients.discus-moth.ts.net:8081
  key: API_KEY
  fields: ["rate", "queue", "timeleft"]
```

### Jellyfin Widget

```yaml
widget:
  type: jellyfin
  url: http://jellyfin.discus-moth.ts.net:8096
  key: API_KEY
  enableBlocks: true
  enableNowPlaying: true
  fields: ["movies", "series", "episodes"]
```

**Note**: Jellyfin widget requires `jellyfin.discus-moth.ts.net` (not localhost) because Jellyfin is on a different VM.

## Docker Integration

Homepage can show Docker container status if configured.

1. Create `docker.yaml`:

   ```yaml
   my-docker:
     host: unix:///var/run/docker.sock
   ```

2. The compose file already mounts Docker socket (read-only):

   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock:ro
   ```

3. Restart Homepage

Container status dots will appear on services running in Docker.

## Troubleshooting

### Widgets Not Loading

**Symptom**: Widget shows "Error" or no data

**Diagnosis**:
```bash
# Check Homepage logs

docker logs homepage | grep -i error

# Test API connectivity

curl -H "X-Api-Key: YOUR_SONARR_KEY" http://localhost:8989/api/v3/system/status
```

**Solutions**:

1. **Wrong API Key**:
   - Verify API key is correct
   - Copy from service settings (no extra spaces)
   - Update `services.yaml` with correct key

2. **Wrong URL**:
   - For same-VM services: use `http://localhost:PORT`
   - For other VMs: use full Tailscale hostname or IP
   - Don't include `/api` in the base URL

3. **Service Authentication**:
   - Ensure service has authentication enabled
   - Sonarr/Radarr: Settings → General → Authentication → Form

4. **Network Connectivity**:

   ```bash
   # From within Homepage container
   docker exec homepage curl http://localhost:8989/api/v3/system/status
   ```

### Can't Access Dashboard

**Symptom**: Browser shows connection refused

**Diagnosis**:
```bash
# Check if container is running

docker ps | grep homepage

# Check logs

docker logs homepage

# Check if port is listening

sudo netstat -tulpn | grep 3000
```

**Solutions**:

1. **Container not running**:

   ```bash
   cd /opt/media-stack
   docker compose up -d homepage
   ```

2. **Port conflict**:

   ```bash
   # Check what's using port 3000
   sudo lsof -i :3000
   ```

3. **Firewall blocking**:

   ```bash
   sudo ufw allow 3000/tcp
   ```

### Configuration Changes Not Applied

**Always restart Homepage after configuration changes**:
```bash
docker restart homepage

# Or recreate to pull config changes

cd /opt/media-stack
docker compose up -d homepage
```

### Jellyfin Widget Not Working

Jellyfin requires API key generated in Jellyfin UI:

1. Login to Jellyfin → Dashboard
2. Navigate to **Advanced** → **API Keys**
3. Click **+** to create new key
4. Name it "Homepage"
5. Copy the API key
6. Update `services.yaml` with the key
7. Restart Homepage

### Permission Issues

If Homepage can't read config files:

```bash
# Fix permissions

sudo chown -R 1000:1000 /opt/media-stack/homepage
sudo chmod -R 755 /opt/media-stack/homepage
```

## Advanced Configuration

### Custom CSS

Add custom styling via `custom.css`:

```bash
cd /opt/media-stack/homepage
sudo nano custom.css
```

```css
/* Example: Custom background */
body {
  background-image: url('your-background.jpg');
}
```

Reference in `settings.yaml`:
```yaml
customCSS: /app/config/custom.css
```

### Custom Icons

Place custom icons in `/opt/media-stack/homepage/icons/`:

```bash
sudo mkdir -p /opt/media-stack/homepage/icons
sudo cp your-icon.png /opt/media-stack/homepage/icons/
```

Reference in `services.yaml`:
```yaml
icon: /icons/your-icon.png
```

### Multi-Language Support

Homepage supports multiple languages:

```yaml
# settings.yaml

language: en  # en, es, fr, de, etc.
```

## Backup Configuration

```bash
# Backup Homepage config

sudo tar -czf homepage-config-backup-$(date +%Y%m%d).tar.gz \
  /opt/media-stack/homepage

# Copy to NAS

sudo cp homepage-config-backup-*.tar.gz /mnt/data/backups/
```

## Update Homepage

```bash
# SSH to media-services VM

ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest image and restart

cd /opt/media-stack
docker compose pull homepage
docker compose up -d homepage
```

## Resources

- **Official Documentation**: https://gethomepage.dev
- **Widget Library**: https://gethomepage.dev/widgets/
- **Icon Library**: https://github.com/walkxcode/dashboard-icons
- **GitHub**: https://github.com/gethomepage/homepage

## See Also

- [Service Endpoints](../configuration/service-endpoints.md)
- [Portainer Setup](portainer-setup.md)
- [Service Integration Checklist](../configuration/service-integration-checklist.md)
- [Common Issues](../troubleshooting/common-issues.md)
