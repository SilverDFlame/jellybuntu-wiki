# VM Specifications Reference

Complete hardware, network, and service configuration for all VMs in the Jellybuntu infrastructure.

## Home Assistant (VMID 100)

**Hardware:**

- **Cores:** 2 (shared)
- **CPU Type:** host
- **CPU Units:** 1024 (medium priority)
- **Memory:** 2GB (2048MB)
- **Disk:** 40GB (local-zfs)
- **Network:** virtio bridge (vmbr0)

**Network:**

- **IP:** 192.168.0.10
- **Hostname:** home-assistant.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services:**

- Home Assistant (Quadlet/Podman)

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 8123 | TCP | Home Assistant Web UI | Local + Tailscale |

**Storage:**

- Quadlet files: `~/.config/containers/systemd/`
- Data directory: `/mnt/data` (NFS from Btrfs NAS)

---

## Satisfactory Server (VMID 200)

**Hardware:**

- **Cores:** 4 (pinned to physical cores 4-7)
- **CPU Pinning:** 4-7 (dedicated cores)
- **CPU Type:** host
- **CPU Units:** 2048 (high priority)
- **Memory:** 8GB (8192MB)
- **Disk:** 60GB (local-zfs)
- **Network:** virtio bridge (vmbr0)
- **NUMA:** Disabled

**Network:**

- **IP:** 192.168.0.11
- **Hostname:** satisfactory-server.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services:**

- Satisfactory Dedicated Server (SteamCMD + systemd)

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 7777 | TCP | Game Port / Server API | Local + Tailscale |
| 8888 | TCP | Server Manager HTTPS | Local + Tailscale |

---

## NAS - Btrfs RAID1 (VMID 300)

**Hardware:**

- **Cores:** 2 (shared)
- **CPU Type:** host
- **CPU Units:** 1024 (medium priority)
- **Memory:** 6GB (6144MB)
- **Boot Disk:** 32GB (local-zfs)
- **Storage Disks:** 3x 6TB (passthrough for Btrfs RAID1)
- **Network:** virtio bridge (vmbr0)

**Network:**

- **IP:** 192.168.0.15
- **Hostname:** nas.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services:**

- Btrfs filesystem with RAID1
- NFS server
- Automatic snapshots

**Storage:**

- **Btrfs Pool:** `/mnt/storage` (RAID1 mirror)
- **NFS Export:** `/mnt/storage/data`
- **Permissions:** 770 (UID/GID 3000)
- **Snapshots:** Automatic via systemd timers

**NFS Clients:**

- media-services.discus-moth.ts.net (192.168.0.13)
- download-clients.discus-moth.ts.net (192.168.0.14)
- jellyfin.discus-moth.ts.net (192.168.0.12)
- home-assistant.discus-moth.ts.net (192.168.0.10)

---

## Jellyfin (VMID 400)

**Hardware:**

- **Cores:** 4 (shared, increased for 4K transcoding)
- **CPU Type:** host
- **CPU Flags:** +aes (better codec performance)
- **CPU Units:** 2048 (high priority)
- **Memory:** 8GB (8192MB)
- **Disk:** 80GB (local-zfs)
- **Network:** virtio bridge (vmbr0)
- **GPU Passthrough:** No (Matrox G200eW is management only)

**CPU Optimizations:**

- **Governor:** performance
- **Scheduling Priority:** Nice=-10 (high priority)
- **IO Priority:** realtime class
- **System Limits:** Increased memlock, nofile

**Network:**

- **IP:** 192.168.0.12
- **Hostname:** jellyfin.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services:**

- Jellyfin Media Server (native package, not Docker)

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 8096 | TCP | HTTP Web UI | Local + Tailscale |
| 8920 | TCP | HTTPS Web UI | Local + Tailscale |
| 7359 | UDP | Service Discovery | Local + Tailscale |

**Storage:**

- Data directory: `/mnt/data` (NFS from Btrfs NAS)
- Media paths:
  - TV Shows: `/mnt/data/media/tv`
  - Movies: `/mnt/data/media/movies`

**Transcoding:**

- Software transcoding only (no hardware acceleration)
- 4 cores allocated for parallel transcoding
- CPU governor set to performance mode

---

## Media Services Stack (VMID 401)

**Hardware:**

- **Cores:** 4 (shared)
- **CPU Type:** host
- **CPU Units:** 1024 (medium priority)
- **Memory:** 8GB (8192MB)
- **Disk:** 50GB (local-zfs)
- **Network:** virtio bridge (vmbr0)

**Network:**

- **IP:** 192.168.0.13
- **Hostname:** media-services.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services (Quadlet/Podman):**

- Sonarr (TV show management)
- Radarr (movie management)
- Prowlarr (indexer management)
- Jellyseerr (request management)
- Bazarr (subtitle management)
- Huntarr (missing content discovery)
- Homarr (dashboard)
- Flaresolverr (Cloudflare bypass)
- Recyclarr (custom formats/quality profiles)

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 8989 | TCP | Sonarr Web UI | Local + Tailscale |
| 7878 | TCP | Radarr Web UI | Local + Tailscale |
| 9696 | TCP | Prowlarr Web UI | Local + Tailscale |
| 5055 | TCP | Jellyseerr Web UI | Local + Tailscale |
| 8191 | TCP | Flaresolverr API | Local + Tailscale |

**Storage:**

- Quadlet files: `~/.config/containers/systemd/`
- Data directory: `/mnt/data` (NFS from Btrfs NAS)
- Media paths:
  - TV Shows: `/mnt/data/media/tv`
  - Movies: `/mnt/data/media/movies`

---

## Download Clients (VMID 402)

**Hardware:**

- **Cores:** 4 (shared)
- **CPU Type:** host
- **CPU Units:** 1024 (medium priority)
- **Memory:** 6GB (6144MB)
- **Disk:** 60GB (local-zfs)
- **Network:** virtio bridge (vmbr0)

**Network:**

- **IP:** 192.168.0.14
- **Hostname:** download-clients.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services (Quadlet/Podman):**

- Gluetun (VPN client)
- qBittorrent (torrent client)
- SABnzbd (usenet client)
- Unpackerr (automatic extraction)

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 8080 | TCP | qBittorrent Web UI | Local + Tailscale |
| 8081 | TCP | SABnzbd Web UI | Local + Tailscale |
| 6881 | TCP | qBittorrent Incoming | Internet |
| 6881 | UDP | qBittorrent Incoming | Internet |

**Storage:**

- Quadlet files: `~/.config/containers/systemd/`
- Data directory: `/mnt/data` (NFS from Btrfs NAS)
- Torrent paths:
  - TV: `/mnt/data/torrents/tv`
  - Movies: `/mnt/data/torrents/movies`
  - Incomplete: `/mnt/data/torrents/incomplete`
- Usenet paths:
  - TV: `/mnt/data/usenet/tv`
  - Movies: `/mnt/data/usenet/movies`
  - Incomplete: `/mnt/data/usenet/incomplete`

**SABnzbd Configuration:**

- Host whitelist: `download-clients.discus-moth.ts.net`
- Local ranges: 192.168.0.0/16, 172.16.0.0/12, 100.64.0.0/10 (Tailscale)
- API access for Sonarr/Radarr

---

## Monitoring (VMID 500) - Phase 5 (Optional)

**Hardware:**

- CPU: 2 cores (host type, shared, no pinning)
- RAM: 4GB (4096MB)
- Disk: 64GB (local-zfs storage)
- CPU Units: 1024 (medium priority)

**Network:**

- IP: 192.168.0.16
- Tailscale: monitoring.discus-moth.ts.net
- Bridge: vmbr0

**Services:**

- Prometheus - Metrics collection and storage
- Alertmanager - Alert routing and deduplication
- Grafana - Visualization and dashboards
- SNMP Exporter - Network device monitoring
- Blackbox Exporter - Endpoint monitoring
- cAdvisor - Container metrics

**Note:** Uptime Kuma moved to external monitoring (Oracle Cloud)

**Deployment:**

- Stack: Quadlet/Podman (rootless)
- Quadlet files: `~/.config/containers/systemd/`
- Data directory: `/opt/monitoring/data`
- Boot order: 7 (starts after core services)
- Start delay: 20 seconds
- Shutdown delay: 60 seconds

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 9090 | TCP | Prometheus | Local + Tailscale |
| 9093 | TCP | Alertmanager | Local + Tailscale |
| 3000 | TCP | Grafana | Local + Tailscale |
| 9116 | TCP | SNMP Exporter | Localhost |
| 9115 | TCP | Blackbox Exporter | Localhost |

**Exporters (Deployed on Other VMs):**

- node_exporter (port 9100) - System metrics on all VMs + Proxmox host
- cAdvisor (port 8180) - Container metrics on Docker VMs (Media Services, Download Clients, Jellyfin)

**Storage:**

- Prometheus data: `/opt/monitoring/data/prometheus`
- Grafana data: `/opt/monitoring/data/grafana`
- Alertmanager data: `/opt/monitoring/data/alertmanager`
- Config files: `/opt/monitoring/config`

**Podman Compose Structure:**

- Main file: `docker-compose-monitoring.yml`
- Network: `monitoring_net` (bridge)
- Resource limits:
  - Prometheus: 2GB RAM, 1.0 CPU
  - Grafana: 1GB RAM, 0.5 CPU
  - Alertmanager: 512MB RAM, 0.25 CPU
  - Exporters: 256MB RAM, 0.25 CPU each

**Monitoring Targets:**

- Proxmox host (node_exporter + SNMP)
- All 6 core VMs (node_exporter)
- Docker containers (cAdvisor on 3 VMs)
- Service endpoints (Blackbox Exporter)
- Network devices (SNMP Exporter)

**Deployment Playbooks:**

- [`playbooks/core/15-provision-monitoring-vm.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/15-provision-monitoring-vm.yml) - Creates VMID 500
- [`playbooks/core/16-deploy-monitoring-exporters.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/16-deploy-monitoring-exporters.yml) - Installs exporters on all VMs
- [`playbooks/core/17-configure-monitoring-stack.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/17-configure-monitoring-stack.yml) - Deploys Prometheus/Grafana/Uptime Kuma
- [`playbooks/phases/phase5-monitoring.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/phases/phase5-monitoring.yml) - Orchestrates all three

---

## UniFi Controller (VMID 800)

**Hardware:**

- **Cores:** 2 (shared)
- **CPU Type:** host
- **CPU Units:** 1024 (medium priority)
- **Memory:** 4GB (4096MB)
- **Disk:** 32GB (local-zfs)
- **Network:** virtio bridge (vmbr0)

**Network:**

- **IP:** 192.168.0.19
- **Hostname:** unifi-controller.discus-moth.ts.net
- **Gateway:** 192.168.0.1
- **DNS:** 9.9.9.9, 192.168.0.1

**Services (Quadlet/Podman):**

- UniFi Network Application
- MongoDB 7.0

**Ports:**

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 8443 | TCP | Web UI (HTTPS) | Local + Tailscale |
| 8080 | TCP | Device Inform | Local only |
| 3478 | UDP | STUN | Local only |
| 10001 | UDP | Device Discovery | Local only |

**Storage:**

- Quadlet files: `~/.config/containers/systemd/`
- Config directory: `/opt/unifi/config`
- MongoDB data: `/opt/unifi/mongodb`
- Logs: `/opt/unifi/logs`

---

## Resource Allocation Summary

| VM | VMID | Cores | Pinning | CPU Type | CPU Units | Priority | RAM | Disk | Special Flags |
|----|------|-------|---------|----------|-----------|----------|-----|------|---------------|
| Home Assistant | 100 | 2 | No | host | 1024 | Medium | 2GB | 40GB | - |
| Satisfactory | 200 | 4 | 4-7 | host | 2048 | High | 8GB | 60GB | numa=0 |
| NAS (Btrfs RAID1) | 300 | 2 | No | host | 1024 | Medium | 6GB | 32GB + 3x6TB | - |
| Jellyfin | 400 | 4 | No | host | 2048 | High | 8GB | 80GB | +aes |
| Media Services | 401 | 4 | No | host | 1024 | Medium | 8GB | 50GB | - |
| Download Clients | 402 | 4 | No | host | 1024 | Medium | 6GB | 60GB | - |
| Monitoring | 500 | 2 | No | host | 1024 | Medium | 4GB | 64GB | - |
| Woodpecker CI | 600 | 2 | No | host | 512 | Low | 8GB | 32GB | - |
| Lancache | 700 | 2 | No | host | 512 | Low | 4GB | 32GB | - |
| UniFi Controller | 800 | 2 | No | host | 1024 | Medium | 4GB | 32GB | - |
| **Total** | | **28** | | | | | **58GB** | **482GB + 6TB** | |

**Physical Host Resources:**

- 16 physical CPU cores / 32 threads (AMD EPYC 7313P)
- 128GB RAM
- NVMe boot + 3x 6TB Btrfs RAID1 (~9TB usable) + 32GB RAM disk (transcoding)
- ~175% CPU overprovisioning (28 virtual / 16 physical)

**CPU Overprovisioning Strategy:**

- Bursty workloads (transcoding, downloads, scanning)
- Priority system via `cpu_units` ensures critical VMs get cycles
- Dedicated cores for Satisfactory (real-time game server needs)

---

## Network Configuration

**Bridge:** vmbr0 (Proxmox)
**Subnet:** 192.168.0.0/24
**Gateway:** 192.168.0.1
**DNS:** 9.9.9.9 (Quad9), 192.168.0.1 (local router)

**Tailscale Mesh VPN:**

- Network: 100.64.0.0/10 (CGNAT range)
- Domain: discus-moth.ts.net
- Auto-approval via ACLs
- Ephemeral auth keys

**Firewall (UFW):**

- SSH from Tailscale (100.64.0.0/10) + LAN (192.168.0.0/24)
- Service ports open to local network (192.168.0.0/24) and Tailscale
- Default deny for other traffic

---

## Storage Architecture

**NFS Server:** Btrfs NAS (192.168.0.15)

- Pool: `storage` (Btrfs RAID1, 3x 6TB mirror, ~9TB usable)
- Export: `/mnt/storage/data`
- Permissions: 770 (UID/GID 3000)
- Snapshots: Automatic via systemd timers

**NFS Clients:**

- Jellyfin: `/mnt/data` (media playback)
- Media Services: `/mnt/data` (media management)
- Download Clients: `/mnt/data` (downloads)
- Home Assistant: `/mnt/data` (backups and data)

**Folder Structure (Trash Guides):**

```text
/mnt/storage/data/
├── media/
│   ├── tv/          (Sonarr managed, Jellyfin library)
│   └── movies/      (Radarr managed, Jellyfin library)
├── torrents/
│   ├── tv/          (qBittorrent completed TV)
│   ├── movies/      (qBittorrent completed movies)
│   └── incomplete/  (qBittorrent active downloads)
└── usenet/
    ├── tv/          (SABnzbd completed TV)
    ├── movies/      (SABnzbd completed movies)
    └── incomplete/  (SABnzbd active downloads)
```

**Hardlink Support:**

- Download folders and media folders on same filesystem
- Allows instant "moves" via hardlinks
- Saves storage space for seeding

---

## Authentication & Access

**SSH Access:**

- Key: `~/.ssh/ansible_homelab`
- User: `ansible` (passwordless sudo)
- After firewall: Tailscale (100.64.0.0/10) + LAN (192.168.0.0/24)

**Proxmox API:**

- User: `ansible@pve`
- Password: SOPS-encrypted ([`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml))
- Required permissions: VM.*, Datastore.*, SDN.*

**Tailscale:**

- Ephemeral auth keys (generated via API)
- Auto-approval via ACL tags
- Keys stored in secrets file ([`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml))

---

## Cloud-Init Template

**Template VMID:** 9000
**Base Image:** Ubuntu 24.04 Noble (cloud-img)
**Configuration:**

- SSH key-only authentication
- Ansible user with passwordless sudo
- No default passwords
- All VMs cloned from this template

---

## See Also

- [Architecture Overview](../architecture.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Networking Configuration](../configuration/networking.md)
- [Playbooks Reference](playbooks.md)
