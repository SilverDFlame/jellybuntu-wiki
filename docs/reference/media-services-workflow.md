# Media Services Deployment Workflow

This document outlines the complete workflow for deploying media services with Trash Guides folder structure and NFS
storage integration.

## Overview

The media services stack uses **Trash Guides recommended folder structure** for optimal hardlinks support. The
deployment is fully automated through phase-based playbooks:

- **Phase 1 (Infrastructure)**: Provision all VMs on Proxmox
- **Phase 2 (Networking)**: Configure Btrfs NAS storage + Tailscale VPN
- **Phase 3 (Services)**: Deploy all applications with NFS storage from the start

## Deployment

The media services are deployed using phase-based playbooks that automate the entire setup:

### Phase 1: Infrastructure (playbooks/main-phase1-infrastructure.yml)

**Purpose**: Provision all VMs on Proxmox

**Execution**:

```bash
./bin/runtime/ansible-run.sh playbooks/main-phase1-infrastructure.yml
```

**What It Creates**:

- Home Assistant VM (VMID 100, .10)
- Satisfactory Server VM (VMID 200, .11)
- NAS VM (VMID 300, .15) - For Btrfs RAID1 storage
- Jellyfin VM (VMID 400, .12)
- Media Services VM (VMID 401, .13) - Sonarr, Radarr, Prowlarr, Jellyseerr
- Download Clients VM (VMID 402, .14) - qBittorrent, SABnzbd

### Phase 2: Networking (playbooks/main-phase2-networking.yml)

**Purpose**: Configure Btrfs NAS storage and Tailscale VPN

**Execution**:

```bash
./bin/runtime/ansible-run.sh playbooks/main-phase2-networking.yml
```

**What It Does**:

1. **Configures Btrfs NAS** (playbook 02-configure-nas-role):
   - Creates Btrfs RAID1 filesystem on two disks
   - Mounts at `/mnt/storage`
   - Creates Trash Guides folder structure at `/mnt/storage/data`
   - Configures NFS server with export at `/mnt/storage/data`
   - Creates nfsuser (UID/GID 3000)

2. **Installs Tailscale** (playbook 03-configure-tailscale-role):
   - Installs Tailscale on all VMs (including NAS)
   - Joins VMs to Tailscale network with auto-approval
   - Configures hostnames (*.discus-moth.ts.net)

**Outcome After Phase 2**:

- ✅ Btrfs NAS ready with NFS storage at 192.168.0.15:/mnt/storage/data
- ✅ All VMs accessible via Tailscale
- ✅ Ready for service deployment

### Phase 3: Services (playbooks/main-phase3-services.yml)

**Purpose**: Deploy all applications with NFS storage

**Execution**:

```bash
./bin/runtime/ansible-run.sh playbooks/main-phase3-services.yml
```

**What It Deploys**:

1. **Home Assistant** (playbook 04-configure-home-assistant-role):
   - Docker container with Home Assistant
   - Access: http://home-assistant.discus-moth.ts.net:8123

2. **Satisfactory Server** (playbook 05-configure-satisfactory-role):
   - Dedicated game server with CPU pinning
   - Access: satisfactory-server.discus-moth.ts.net:7777

3. **Media Services** (playbook 06-configure-media-services-role):
   - Installs Docker on media-services VM (.13)
   - Mounts NFS from Btrfs NAS: `/mnt/data` → `192.168.0.15:/mnt/storage/data`
   - Deploys Sonarr (8989), Radarr (7878), Prowlarr (9696), Jellyseerr (5055), Byparr (8191), Recyclarr
   - Creates Docker Compose file with proper volume mappings

4. **Download Clients** (playbook 07-configure-download-clients-role):
   - Installs Docker on download-clients VM (.14)
   - Mounts NFS from Btrfs NAS: `/mnt/data` → `192.168.0.15:/mnt/storage/data`
   - Deploys qBittorrent (8080) and SABnzbd (8081)
   - Applies SABnzbd configuration automatically
   - **qBittorrent auto-configured**: Categories (tv, movies) with proper paths, Automatic Torrent Management enabled

5. **Byparr** (deployed as part of playbook 06-configure-media-services-role):
   - Cloudflare bypass for indexers (port 8191)
   - Uses Camoufox browser (Firefox-based)

6. **Recyclarr** (playbook 08-configure-recyclarr-role):
   - Custom formats and quality profiles from Trash Guides
   - Requires API keys in secrets file

7. **NFS Client Mounts** (playbook 10-configure-nfs-clients-role):
   - Ensures all client VMs have NFS mounted properly
   - Mounts at `/mnt/data` with proper permissions

8. **Jellyfin** (playbook 11-configure-jellyfin-role):
   - Installs Jellyfin on dedicated VM (.12)
   - Mounts NFS at `/mnt/data`
   - CPU governor set to performance
   - High scheduling priority (Nice=-10)
   - Access: http://jellyfin.discus-moth.ts.net:8096

9. **UFW Firewall** (playbook 12-configure-ufw-firewall-role):
   - SSH from Tailscale + LAN (fallback)
   - Allows service access from local network + Tailscale

10. **Unattended Upgrades** (playbook 13-configure-unattended-upgrades-role):
    - Enables automatic security updates

**Outcome After Phase 3**:

- ✅ All services deployed and running
- ✅ All VMs use shared NFS storage from Btrfs NAS
- ✅ Ready for GUI configuration (see below)

---

## GUI Configuration Steps

After Phase 3 deployment, configure services via their web interfaces:

### 1. SABnzbd Configuration

**URL**: http://download-clients.discus-moth.ts.net:8081 (or http://192.168.0.14:8081 before firewall hardening)

**Note**: After Phase 3 completes, direct IP access is restricted by UFW firewall. Use Tailscale hostname instead.

1. **Config → Folders** (already configured by playbook):
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet`

2. **Config → Categories**:
   - Add category `tv`: Folder = `/data/usenet/tv`
   - Add category `movies`: Folder = `/data/usenet/movies`

3. **Config → Servers**:
   - Add your Usenet provider (host, port, username, password)

4. **Config → General → Security**:
   - Copy the API Key (needed for Sonarr/Radarr)

---

### 2. qBittorrent Configuration

**URL**: http://download-clients.discus-moth.ts.net:8080 (or http://192.168.0.14:8080 before firewall hardening)

**Note**: After Phase 3 completes, direct IP access is restricted by UFW firewall. Use Tailscale hostname instead.

**Default Credentials**:

- Username: `admin`
- Password: Check logs: `docker logs qbittorrent 2>&1 | grep password`

**Note**: qBittorrent is **automatically configured** by the playbook with categories (tv, movies) and Automatic Torrent
Management enabled. You only need to verify the configuration:

1. **Options → Downloads** (already configured):
   - Default Save Path: `/data/torrents`
   - Keep incomplete torrents in: `/data/torrents/incomplete`
   - Copy .torrent files to: `/data/torrents/torrent-files`

2. **Options → Downloads → Saving Management** (already configured):
   - ☑ Automatic Torrent Management: **Enabled**
   - Default Torrent Management Mode: **Automatic**

3. **Categories** (already created):
   - Category: `tv` → Save path: `/data/torrents/tv`
   - Category: `movies` → Save path: `/data/torrents/movies`

---

### 3. Prowlarr Configuration

**URL**: http://media-services.discus-moth.ts.net:9696

1. **Settings → General → Security**:
   - Copy the API Key

2. **Indexers → Add Indexer**:
   - Add your preferred indexers (torrent and/or Usenet)

3. **Settings → Apps → Add Application**:
   - **Add Sonarr**:
     - Prowlarr Server: `http://localhost:9696`
     - Sonarr Server: `http://sonarr:8989`
     - API Key: (from Sonarr Settings → General → Security)

   - **Add Radarr**:
     - Prowlarr Server: `http://localhost:9696`
     - Radarr Server: `http://radarr:7878`
     - API Key: (from Radarr Settings → General → Security)

4. **Settings → Download Clients → Add Download Client**:
   - **Add qBittorrent**:
     - Host: `download-clients.discus-moth.ts.net` (or `192.168.0.14` before firewall hardening)
     - Port: `8080`
     - Username: `admin`
     - Password: (from qBittorrent)

   - **Add SABnzbd**:
     - Host: `download-clients.discus-moth.ts.net` (or `192.168.0.14` before firewall hardening)
     - Port: `8081`
     - API Key: (from SABnzbd)

---

### 4. Sonarr Configuration

**URL**: http://media-services.discus-moth.ts.net:8989

1. **Settings → Media Management → Root Folders**:
   - Add root folder: `/data/media/tv`

2. **Settings → Download Clients → Add Download Client**:
   - **Add qBittorrent**:
     - Host: `qbittorrent`
     - Port: `8080`
     - Category: `tv`
     - Username: `admin`
     - Password: (from qBittorrent)

   - **Add SABnzbd**:
     - Host: `sabnzbd`
     - Port: `8080`
     - API Key: (from SABnzbd)
     - Category: `tv`

3. **Settings → Indexers**:
   - Should auto-populate from Prowlarr

**Verification**:

- Add a TV show
- Monitor episode and trigger download
- Verify file goes to `/data/torrents/tv` or `/data/usenet/tv`
- After completion, verify Sonarr imports to `/data/media/tv`

---

### 5. Radarr Configuration

**URL**: http://media-services.discus-moth.ts.net:7878

1. **Settings → Media Management → Root Folders**:
   - Add root folder: `/data/media/movies`

2. **Settings → Download Clients → Add Download Client**:
   - **Add qBittorrent**:
     - Host: `qbittorrent`
     - Port: `8080`
     - Category: `movies`
     - Username: `admin`
     - Password: (from qBittorrent)

   - **Add SABnzbd**:
     - Host: `sabnzbd`
     - Port: `8080`
     - API Key: (from SABnzbd)
     - Category: `movies`

3. **Settings → Indexers**:
   - Should auto-populate from Prowlarr

**Verification**:

- Add a movie
- Trigger download
- Verify file goes to `/data/torrents/movies` or `/data/usenet/movies`
- After completion, verify Radarr imports to `/data/media/movies`

---

### 6. Jellyseerr Configuration

**URL**: http://media-services.discus-moth.ts.net:5055

1. **Initial Setup**:
   - Configure Jellyfin server connection (if using Jellyfin)
   - Or configure Plex/Emby

2. **Settings → Services**:
   - **Add Sonarr**:
     - Server: `http://sonarr:8989`
     - API Key: (from Sonarr)

   - **Add Radarr**:
     - Server: `http://radarr:7878`
     - API Key: (from Radarr)

**Verification**: Request a movie/show and verify it appears in Radarr/Sonarr

---

### 7. Jellyfin Configuration (After Phase 2)

**URL**: http://jellyfin.discus-moth.ts.net:8096

1. **Complete initial setup wizard**

2. **Add media libraries**:
   - Add Library → TV Shows → Path: `/mnt/data/media/tv`
   - Add Library → Movies → Path: `/mnt/data/media/movies`

3. **Verify automatic detection**:
   - Jellyfin should automatically detect new media added by Sonarr/Radarr

---

### 8. Recyclarr Configuration (Optional)

If API keys were added to the secrets file, Recyclarr was automatically configured. To sync custom formats:

```bash
# SSH to media-services VM
ssh ansible@media-services.discus-moth.ts.net

# Run sync
cd /opt/media-stack
docker exec recyclarr recyclarr sync
```

Verify in Sonarr/Radarr:

- Sonarr → Settings → Profiles → WEB-1080p (should have custom formats)
- Radarr → Settings → Profiles → HD Bluray + WEB (should have custom formats)

---

## Verification Checklist

After completing Phase 3 and GUI configuration:

### NFS Storage

- [ ] NFS mount is active at `/mnt/data` on media-services VM (192.168.0.13)
- [ ] NFS mount is active at `/mnt/data` on download-clients VM (192.168.0.14)
- [ ] NFS mount is active at `/mnt/data` on Jellyfin VM (192.168.0.12)
- [ ] Containers can write to NFS: `docker exec sonarr touch /data/test`

### Download Clients

- [ ] SABnzbd can download to `/mnt/data/usenet/*` with correct categories
- [ ] qBittorrent can download to `/mnt/data/torrents/*` with correct categories
- [ ] qBittorrent categories configured (tv, movies) with proper paths
- [ ] Automatic Torrent Management is enabled in qBittorrent

### Media Management

- [ ] Prowlarr can search indexers and send to both download clients
- [ ] Sonarr receives completed TV downloads and imports to `/mnt/data/media/tv`
- [ ] Radarr receives completed movie downloads and imports to `/mnt/data/media/movies`
- [ ] Jellyseerr can send requests to Sonarr/Radarr
- [ ] All files have proper ownership (3000:3000) and permissions (775)

### Jellyfin

- [ ] Jellyfin can read media files organized by Sonarr/Radarr
- [ ] Jellyfin libraries auto-update when new media is added

### Performance

- [ ] Hardlinks work (file in both download folder and media folder uses same inode)

---

## Troubleshooting

For comprehensive troubleshooting, see:

- **[General Troubleshooting](../troubleshooting/common-issues.md)** - General diagnostic approach
- **[Download Clients](../troubleshooting/download-clients.md)** - qBittorrent/SABnzbd issues
- **[Sonarr/Radarr](../troubleshooting/sonarr-radarr.md)** - Media management issues
- **[Jellyfin](../troubleshooting/jellyfin.md)** - Media server issues
- **[NAS/NFS](../troubleshooting/nas-nfs.md)** - Storage and mount issues
- **[Networking](../troubleshooting/networking.md)** - Tailscale, firewall, SSH issues

### Quick Fixes

**Permission Denied Errors:**

```bash
# On media-services or download-clients VM
sudo chown -R 3000:3000 /mnt/data
sudo chmod -R 775 /mnt/data
```

**NFS Mount Issues:**

```bash
# Verify NFS exports on Btrfs NAS
showmount -e 192.168.0.15

# Test manual mount
sudo mount -t nfs 192.168.0.15:/mnt/storage/data /mnt/test
```

**Container Can't Write:**

```bash
# Check container user (should show PUID=3000)
sudo docker exec sonarr id

# Check directory ownership
ls -la /mnt/data  # Should show 3000:3000
```

**Hardlinks Not Working:**

```bash
# Verify same filesystem
df /mnt/data/torrents /mnt/data/media  # Should show same device

# Test hardlink creation
touch /mnt/data/test1
ln /mnt/data/test1 /mnt/data/test2
ls -li /mnt/data/test*  # Should show same inode
```

---

## Summary

The media services deployment is fully automated through three phases:

- **Phase 1 (Infrastructure)**: Provisions all VMs on Proxmox, including a dedicated NAS VM for Btrfs RAID1 storage
- **Phase 2 (Networking)**: Configures Btrfs NAS with NFS exports and installs Tailscale on all VMs for secure remote access
- **Phase 3 (Services)**: Deploys all applications with NFS storage from the start, eliminating the need for manual migration

All services use the **Trash Guides folder structure** at `/mnt/data` (NFS-mounted from
`192.168.0.15:/mnt/storage/data`), ensuring optimal hardlinks support and efficient storage utilization. After Phase 3
completes, only GUI configuration is needed - all infrastructure, storage, and service deployment is automated.
