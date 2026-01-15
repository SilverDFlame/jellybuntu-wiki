# Docker Compose Memory Limits Patches

**Date**: 2025-10-31
**Purpose**: Add memory limits to all containers to resolve 18 ContainerHighMemory alerts

## Quick Apply

### Automated Script (Recommended)

```bash
cd /home/olieran/coding/mirrors/jellybuntu

# Dry run - see what would change
./scripts/add-memory-limits.sh --dry-run

# Apply changes with backup
./scripts/add-memory-limits.sh --backup

# Manual: Edit download clients and cAdvisor (see below)
```

---

## Manual Patches

### Format

Add this section after the `restart:` line in each service file:

```yaml
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: <LIMIT>
        reservations:
          memory: <RESERVATION>
```

---

## Media Services VM (`compose_files/services/`)

### sonarr.yml

```yaml
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./sonarr:/config
      - /mnt/data:/data
    ports:
      - 8989:8989
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### radarr.yml

```yaml
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./radarr:/config
      - /mnt/data:/data
    ports:
      - 7878:7878
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### prowlarr.yml

```yaml
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### bazarr.yml

```yaml
services:
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./bazarr:/config
      - /mnt/data/media:/data/media
    ports:
      - 6767:6767
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### jellyseer.yml

```yaml
services:
  jellyseer:
    image: docker.io/fallenbagel/jellyseerr:2.1.0
    container_name: jellyseer
    environment:
      - TZ=UTC
    volumes:
      - ./jellyseerr:/app/config
    ports:
      - 5055:5055
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### flaresolverr.yml

```yaml
services:
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - TZ=UTC
    ports:
      - 8191:8191
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### portainer.yml

```yaml
services:
  portainer:
    image: docker.io/portainer/portainer-ce:2.24.0
    container_name: portainer
    volumes:
      - ./portainer:/data
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
    ports:
      - 9000:9000
      - 9443:9443
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
```

### homepage.yml

```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:v0.10.11
    container_name: homepage
    environment:
      - TZ=UTC
    volumes:
      - ./services/homepage:/app/config
    ports:
      - 3000:3000
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### huntarr.yml

```yaml
services:
  huntarr:
    image: hotio/huntarr:latest
    container_name: huntarr
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./huntarr:/config
    ports:
      - 9705:9705
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### recyclarr (if separate file)

```yaml
services:
  recyclarr:
    image: docker.io/recyclarr/recyclarr:7.4.1
    container_name: recyclarr
    environment:
      - TZ=UTC
    volumes:
      - ./recyclarr:/config
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
```

---

## Download Clients VM (`compose_files/docker-compose-downloads.yml`)

### qbittorrent

```yaml
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
      - WEBUI_PORT=8080
    volumes:
      - ./qbittorrent:/config
      - /mnt/data:/data
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 6G
        reservations:
          memory: 4G
```

### sabnzbd

```yaml
services:
  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    container_name: sabnzbd
    environment:
      - PUID={{ nfs_uid }}
      - PGID={{ nfs_gid }}
      - TZ=UTC
    volumes:
      - ./sabnzbd:/config
      - /mnt/data:/data
    ports:
      - 8081:8080
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### gluetun (VPN)

```yaml
services:
  gluetun:
    image: docker.io/qmcgaw/gluetun:v3.41.0
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER={{ vpn_provider }}
      - VPN_TYPE={{ vpn_type }}
      - TZ=UTC
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### unpackerr

```yaml
services:
  unpackerr:
    image: docker.io/golift/unpackerr:0.15.0
    container_name: unpackerr
    environment:
      - TZ=UTC
    volumes:
      - ./unpackerr:/config
      - /mnt/data:/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

---

## Home Assistant VM

### homeassistant

```yaml
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    environment:
      - TZ=UTC
    volumes:
      - ./homeassistant:/config
    ports:
      - 8123:8123
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
```

---

## cAdvisor (All VMs with Docker)

Add to each VM that runs containers:

- home-assistant
- media-services
- download-clients

### cadvisor.yml (create new file in services/)

```yaml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    privileged: true
    ports:
      - 8180:8080
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/containers:/var/lib/containers:ro
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
```

**Note**: cAdvisor is already running based on metrics. Check existing configuration and add memory limits.

---

## Deployment Steps

### Option 1: Automated Script

```bash
cd /home/olieran/coding/mirrors/jellybuntu

# 1. Test dry run
./scripts/add-memory-limits.sh --dry-run

# 2. Apply with backup
./scripts/add-memory-limits.sh --backup

# 3. Review changes
git diff compose_files/

# 4. Manually edit docker-compose-downloads.yml
# (Script doesn't handle multi-service files yet)
```

### Option 2: Manual Editing

```bash
cd /home/olieran/coding/mirrors/jellybuntu/compose_files

# Edit each service file
for service in services/*.yml; do
    echo "Editing $service"
    # Add deploy.resources section after restart: line
done

# Edit downloads compose
vim docker-compose-downloads.yml
```

### Option 3: Ansible Deployment

```bash
# If you have an Ansible role that manages compose files
ansible-playbook playbooks/update-compose-memory-limits.yml
```

---

## Verification

### After Applying Limits

1. **Deploy to VMs** (via Ansible or manual):

   ```bash
   # On each VM
   cd /opt/media-stack  # or compose directory
   podman-compose down
   podman-compose up -d
   ```

2. **Verify limits are applied**:

   ```bash
   # Check container memory limits
   podman inspect sonarr | grep -i memory

   # Should show memory limits in bytes
   # 1G = 1073741824 bytes
   ```

3. **Check Prometheus** (after 5 minutes):

   ```promql
   # Query in Prometheus UI
   container_spec_memory_limit_bytes{name!=""} / 1024 / 1024 / 1024

   # Should show limits like:
   # sonarr: 1
   # radarr: 1
   # qbittorrent: 6
   # etc.
   ```

4. **Check alerts**:

   ```bash
   # Visit Prometheus alerts page
   http://monitoring.discus-moth.ts.net:9090/alerts

   # ContainerHighMemory alerts should clear within 5-10 minutes
   ```

5. **Check Grafana dashboard**:

   ```text
   http://monitoring.discus-moth.ts.net:3000

   # "Container Memory Usage" panels should show percentages < 90%
   ```

---

## Expected Results

### Before

- 18 ContainerHighMemory alerts firing
- All containers showing "+Inf%" memory usage
- No memory limits enforced

### After

- 0 ContainerHighMemory alerts
- Containers showing actual percentage usage
- Memory limits protecting against runaway processes

### Example Expected Percentages (with limits)

- qBittorrent: ~78% (4.7GB / 6GB)
- Sonarr: ~30% (0.30GB / 1GB)
- Radarr: ~20% (0.20GB / 1GB)
- Bazarr: ~42% (0.42GB / 1GB)
- Jellyseerr: ~28% (0.28GB / 1GB)
- FlareSolverr: ~46% (0.46GB / 1GB)
- All others: <50%

---

## Rollback

If containers start OOM killing or crashing:

1. **Increase limits**:

   ```yaml
   # Double the limit
   limits:
     memory: 2G  # was 1G
   ```

2. **Remove limits temporarily**:

   ```bash
   # Comment out deploy section
   #    deploy:
   #      resources:
   #        limits:
   #          memory: 1G
   ```

3. **Restore from backup**:

   ```bash
   # If created with --backup
   cp compose_files/services/sonarr.yml.bak compose_files/services/sonarr.yml
   ```

4. **Check container logs**:

   ```bash
   podman logs sonarr | tail -50
   # Look for OOM errors
   ```

---

## Notes

- **Limits prevent containers from consuming unlimited memory**
- **Reservations guarantee minimum memory allocation**
- **Set limits 2-3x current usage for headroom**
- **Monitor for 24-48 hours after applying**
- **Adjust limits if OOM occurs**

---

## References

- Investigation Results: `logs/memory-investigation-20251031-133602.txt`
- Analysis: `docs/troubleshooting/memory-alerts-analysis-20251031.md`
- Remediation Guide: `docs/troubleshooting/memory-alerts-remediation.md`
