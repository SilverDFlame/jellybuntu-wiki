# Phase 3: Services Deployment

Deploy all applications and services.

## Overview

Phase 3 deploys all homelab services including Home Assistant, Satisfactory, media management stack, download clients,
and Jellyfin.

**Estimated Time**: 8-12 minutes

## Prerequisites

- ✅ Phase 1 completed (VMs provisioned)
- ✅ Phase 2 completed (NAS + Tailscale configured)
- All VMs accessible via Tailscale
- Media services credentials in secrets file

## What Phase 3 Does

### 1. Home Assistant (Docker)

- Deploys Home Assistant container
- Mounts configuration directory
- Exposes port 8123

### 2. Satisfactory Game Server (SteamCMD)

- Installs SteamCMD and dependencies
- Downloads Satisfactory server
- Creates systemd service
- Configures dedicated CPU cores (2-3)

### 3. Media Services (Docker)

Deploys modular Docker Compose stack:

- **Sonarr** (8989) - TV show management
- **Radarr** (7878) - Movie management
- **Prowlarr** (9696) - Indexer management
- **Jellyseerr** (5055) - Request management
- **Byparr** (8191) - Cloudflare bypass

### 4. Download Clients (Docker)

- **qBittorrent** (8080) - **Auto-configured via Web API**:
  - Extracts temporary password from logs
  - Sets download paths (`/data/torrents`)
  - Creates categories (tv-sonarr, radarr)
  - **Sets permanent password from secrets file**
- **SABnzbd** (8081) - Configuration patched after deployment (paths use `/data/usenet`)

### 5. NFS Client Mounts

- Mounts NAS NFS export on all client VMs
- Mount point: `/mnt/data`
- Ensures mounts persist across reboots

### 6. Jellyfin (Native Package)

- Installs Jellyfin via official repository
- Configures CPU governor (performance)
- Sets system limits and scheduling priority
- Optimized for 4K transcoding

## Running Phase 3

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

## Expected Output

```text
PLAY [Deploy Home Assistant] *******************************************
changed: [home-assistant]

PLAY [Deploy Satisfactory] *********************************************
changed: [satisfactory-server]

PLAY [Deploy Media Services] *******************************************
TASK [Deploy Docker Compose stack] *************************************
changed: [media-services]

PLAY [Deploy Download Clients] *****************************************
TASK [Deploy qBittorrent and SABnzbd] **********************************
changed: [download-clients]

TASK [Configure qBittorrent via API] ***********************************
changed: [download-clients]

PLAY [Mount NFS on clients] ********************************************
changed: [media-services]
changed: [download-clients]
changed: [jellyfin]

PLAY [Deploy Jellyfin] *************************************************
changed: [jellyfin]

PLAY RECAP *************************************************************
home-assistant       : ok=8  changed=6
satisfactory-server  : ok=10 changed=8
media-services       : ok=12 changed=10
download-clients     : ok=15 changed=12
jellyfin             : ok=10 changed=8
```

## Verification

### Check Docker Containers (Media Services)

```bash
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker ps"
```

Expected containers:

- sonarr
- radarr
- prowlarr
- jellyseerr
- byparr
- recyclarr

### Check Docker Containers (Download Clients)

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker ps"
```

Expected containers:

- qbittorrent
- sabnzbd

### Verify NFS Mounts

```bash
# Check NFS mount on media services
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "df -h | grep nfs"

# Expected: 192.168.0.15:/mnt/storage/data on /mnt/data
```

> **Note**: NFS mounts use direct IP (192.168.0.15) for reliability under heavy I/O.
> See [NFS Direct IP Migration](../reference/nfs-direct-ip-migration.md).

### Check Jellyfin Service

```bash
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "systemctl status jellyfin"
```

Expected: `Active: active (running)`

### Test qBittorrent Login

Access: http://download-clients.discus-moth.ts.net:8080

- Username: `admin` (or your `vault_services_admin_username`)
- Password: (your `vault_services_admin_password` from setup.sh)

Should login successfully - password was set automatically!

### Verify Service Accessibility

All services should be accessible via Tailscale hostnames:

**Media Services**:

- http://media-services.discus-moth.ts.net:8989 (Sonarr)
- http://media-services.discus-moth.ts.net:7878 (Radarr)
- http://media-services.discus-moth.ts.net:9696 (Prowlarr)
- http://media-services.discus-moth.ts.net:5055 (Jellyseerr)

**Download Clients**:

- http://download-clients.discus-moth.ts.net:8080 (qBittorrent)
- http://download-clients.discus-moth.ts.net:8081 (SABnzbd)

**Media Server**:

- http://jellyfin.discus-moth.ts.net:8096 (Jellyfin)

**Home Automation**:

- http://home-assistant.discus-moth.ts.net:8123 (Home Assistant)

## qBittorrent Auto-Configuration Details

Phase 3 automatically configures qBittorrent via Web API:

1. **Container Starts** with temporary password
2. **Extract Password** from container logs
3. **Authenticate** via API using temp password
4. **Configure Preferences**:
   - Save path: `/data/torrents`
   - Temp path: `/data/torrents/incomplete`
   - Enable pre-allocation
   - Enable incomplete file extension
5. **Create Categories**:
   - `tv-sonarr` → `/data/torrents/tv-sonarr`
   - `radarr` → `/data/torrents/radarr`
6. **Set Permanent Password** from `vault_services_admin_password`
7. **Logout** from API

This means qBittorrent is immediately usable with your vault credentials!

## Troubleshooting

### Docker Containers Not Starting

**Solution**:

```bash
# Check container logs
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker logs sonarr"

# Check Docker service
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl status docker"

# Restart container
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "cd /opt/media-stack && docker compose restart sonarr"
```

### NFS Mount Fails

**Error**: `Mount point does not exist` or `Permission denied`

**Solution**:

```bash
# Verify NFS server is running (from Phase 2)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl status nfs-server"

# Check exports
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo exportfs -v"

# Test manual mount (use direct IP for reliability)
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net
sudo mount 192.168.0.15:/mnt/storage/data /mnt/data
```

### qBittorrent Configuration Fails

**Error**: `Failed to authenticate with qBittorrent`

**Solution**:

```bash
# Check qBittorrent is running
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker ps | grep qbittorrent"

# Check container logs for temp password
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker logs qbittorrent 2>&1 | grep 'temporary password'"

# Verify credentials in secrets file
sops -d group_vars/all.sops.yaml | grep services_admin

# Reset and reconfigure
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "cd /opt/download-clients && docker compose down"
rm -rf /opt/download-clients/services/qbittorrent/config
./bin/runtime/ansible-run.sh playbooks/07-configure-download-clients-role.yml
```

### Jellyfin Won't Start

**Error**: `Failed to start jellyfin.service`

**Solution**:

```bash
# Check service status
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "systemctl status jellyfin"

# View logs
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "sudo journalctl -u jellyfin -n 50"

# Check port availability
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "sudo netstat -tuln | grep 8096"

# Restart service
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "sudo systemctl restart jellyfin"
```

### Service Can't Access NFS Mount

**Error**: Permission denied in `/mnt/data`

**Solution**:

```bash
# Check mount is present
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "mount | grep /mnt/data"

# Check UID/GID match
sops -d group_vars/all.sops.yaml | grep nfs_

# Verify directory permissions on NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "ls -la /mnt/storage/data"

# Fix permissions if needed
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo chown -R 3000:3000 /mnt/storage/data"
```

### Satisfactory Server Won't Start

**Solution**:

```bash
# Check service status
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net \
  "systemctl status satisfactory"

# View logs
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net \
  "sudo journalctl -u satisfactory -n 50"

# Check server files
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net \
  "ls -la /opt/satisfactory"
```

## Playbook Details

**Files**:

- [`playbooks/services/home-assistant.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/home-assistant.yml)
- [`playbooks/services/satisfactory.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/satisfactory.yml)
- [`playbooks/services/media-services.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/media-services.yml)
- [`playbooks/services/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/download-clients.yml)
- [`playbooks/networking/nfs-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/networking/nfs-clients.yml)
- [`playbooks/services/jellyfin.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin.yml)
- [`playbooks/services/jellyfin-config.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin-config.yml) -
  Post-wizard API configuration (run after initial setup)

**Roles**:

- [`roles/docker_compose_app/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/docker_compose_app/) - Docker Compose deployments
- [`roles/nfs_client/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/nfs_client/) - NFS mount configuration
- [`roles/jellyfin/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/jellyfin/) - Jellyfin installation and optimization

**NOT Included in Phase 3**:

- Recyclarr (requires API keys - runs in Phase 4)
- UFW firewall (security hardening - Phase 4)
- Unattended upgrades (Phase 4)

## Docker Compose Structure

Services use modular compose files:

```text
services/compose/
├── docker-compose.yml               # Media services
├── docker-compose-downloads.yml     # Download clients
└── services/                        # Individual service definitions
    ├── sonarr.yml
    ├── radarr.yml
    ├── prowlarr.yml
    ├── jellyseerr.yml
    ├── recyclarr.yml
    ├── qbittorrent.yml
    └── sabnzbd.yml
```

This modular structure makes services easy to update or modify individually.

## Important Notes

### Media Services Login

All services use the same credentials:

- Username: `admin` (or your `vault_services_admin_username`)
- Password: (your `vault_services_admin_password` from setup.sh)

This includes:

- qBittorrent (auto-configured)
- SABnzbd
- Sonarr
- Radarr
- Prowlarr
- Jellyseerr

### Jellyfin First Run

Jellyfin will prompt for initial setup on first access. Configure:

- Admin account
- Media libraries (use `/data/media/tv` and `/data/media/movies`)
- Metadata providers

### What's NOT Configured Yet

After Phase 3, you still need to manually:

1. Retrieve API keys from Sonarr and Radarr
2. Add API keys to vault
3. Configure download clients in Prowlarr/Sonarr/Radarr
4. Add indexers to Prowlarr
5. Run Phase 4 for Recyclarr and security hardening
6. Complete Jellyfin initial wizard, then run
   [`playbooks/services/jellyfin-config.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin-config.yml)
   to automate remaining Jellyfin configuration (libraries, encoding, plugins)

See [post-deployment.md](post-deployment.md) for manual configuration steps.

## Re-Running Phase 3

Phase 3 is mostly idempotent:

```bash
# Safe to re-run
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

**Note**: Re-running will restart containers and may reset some configurations. Use with caution on a running system.

To re-run specific service:

```bash
# Re-deploy just media services
./bin/runtime/ansible-run.sh playbooks/services/media-services.yml

# Re-configure just qBittorrent
./bin/runtime/ansible-run.sh playbooks/services/download-clients.yml
```

## Success Criteria

✅ Phase 3 is complete when:

- [ ] All Docker containers running
- [ ] Jellyfin service active
- [ ] NFS mounts present on all client VMs
- [ ] qBittorrent login works with vault password
- [ ] All web UIs accessible via Tailscale
- [ ] Home Assistant accessible
- [ ] Satisfactory server running (if enabled)

## Next Steps

After Phase 3 completes:

1. ✅ Verify all services accessible
2. ✅ Test qBittorrent login
3. ➡️ Complete [Manual Configuration](post-deployment.md)
4. ➡️ Then proceed to [Phase 4: Security](phase4-post-deployment.md)

## Reference

- [Phase-Based Deployment](phase-based-deployment.md) - All phases overview
- [Post-Deployment Configuration](post-deployment.md) - Manual setup steps
- [Service Endpoints](../configuration/service-endpoints.md) - All service URLs
- [Media Services Workflow](../reference/media-services-workflow.md) - Media automation
