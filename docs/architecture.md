# Architecture Overview

This document describes the infrastructure design, VM layer, and key design patterns of the Jellybuntu homelab.

## Infrastructure Layers

### 1. Proxmox Host Layer

- **Host**: discus-moth.ts.net (jellybuntu)
- **Hardware**: AMD EPYC 7313P (16 cores / 32 threads), 128GB ECC DDR4, GTX 1080 GPU
- **Storage**: NVMe boot + 3x 6TB Btrfs RAID1 (~9TB usable) + 32GB RAM disk (transcoding)
- **Role**: VM provisioning, GPU passthrough, resource allocation
- **Virtualization**: Proxmox VE with cloud-init templates, IOMMU enabled

### 2. VM Layer

All VMs defined in [`infrastructure/terraform/vms.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf) (OpenTofu):

#### Home Automation

- **Home Assistant** (VMID 100)
  - Resources: 2 cores, 2GB RAM, 40GB disk
  - IP: 192.168.0.10
  - Stack: Rootless Podman with Quadlet
  - Priority: Medium (cpu_units: 1024)

#### Game Servers

- **Satisfactory** (VMID 200)
  - Resources: 4 cores (pinned 4-7), 8GB RAM, 60GB disk
  - IP: 192.168.0.11
  - Stack: SteamCMD + systemd service
  - Priority: High (cpu_units: 2048, dedicated cores)
  - Note: Cores 0-3 reserved for future Minecraft server

#### Storage Infrastructure

- **NAS** (VMID 300)
  - Resources: 2 cores, 6GB RAM, 32GB OS disk + 3x 6TB passthrough (Btrfs RAID1)
  - IP: 192.168.0.15
  - Stack: Btrfs RAID1 (~9TB usable), NFS server, AdGuard Home, Nexus Repository (Quadlet)
  - Services: NFS, AdGuard Home (DNS), Nexus Repository (container registry)
  - Priority: Medium (cpu_units: 1024)
  - Purpose: Network storage, internal DNS with ad blocking, container image caching

#### Media Services

- **Jellyfin** (VMID 400)
  - Resources: 4 cores, 8GB RAM, 80GB disk + GTX 1080 GPU passthrough
  - IP: 192.168.0.12
  - Stack: Native Jellyfin package + Tdarr (Quadlet)
  - Optimizations: NVENC hardware transcoding, RAM disk cache, CPU governor (performance)
  - Services: Jellyfin, Tdarr (media transcoding automation)
  - Priority: High (cpu_units: 2048)
  - Purpose: 4K hardware transcoding with NVENC, automated media optimization

- **Media Services Stack** (VMID 401)
  - Resources: 4 cores, 8GB RAM, 50GB disk
  - IP: 192.168.0.13
  - Stack: Rootless Podman with Quadlet
  - Services: Sonarr, Radarr, Prowlarr, Jellyseerr, Bazarr, Huntarr, Homarr, Byparr, Recyclarr
  - Priority: Medium (cpu_units: 1024)

- **Download Clients** (VMID 402)
  - Resources: 4 cores, 6GB RAM, 60GB disk
  - IP: 192.168.0.14
  - Stack: Rootless Podman with Quadlet
  - Services: qBittorrent, SABnzbd, Gluetun (VPN), Unpackerr
  - Priority: Medium (cpu_units: 1024)
  - Purpose: Isolated download operations with VPN protection

#### Monitoring Infrastructure

- **Monitoring** (VMID 500)
  - Resources: 2 cores, 4GB RAM, 64GB disk
  - IP: 192.168.0.16
  - Stack: Rootless Podman with Quadlet
  - Services: Prometheus, Alertmanager, Grafana, SNMP Exporter, Blackbox Exporter
  - Priority: Medium (cpu_units: 1024)
  - Purpose: Internal infrastructure monitoring with Discord alerting
  - Deployment: Phase 5 (optional, standalone)
  - Note: Uptime Kuma moved to external monitoring (Oracle Cloud)

#### CI/CD Infrastructure

- **Woodpecker CI** (VMID 600)
  - Resources: 2 cores, 8GB RAM, 32GB disk
  - IP: 192.168.0.17
  - Stack: Rootless Podman with Quadlet
  - Services: Woodpecker Server, Woodpecker Agent
  - Priority: Low (cpu_units: 512)
  - Purpose: Automated testing, linting, security scanning, and deployment pipelines
  - Deployment: Phase 2 (CI infrastructure)

#### Caching Infrastructure

- **Lancache** (VMID 700)
  - Resources: 2 cores, 4GB RAM, 32GB disk + NFS cache storage
  - IP: 192.168.0.18
  - Stack: **Rootful Podman** with Quadlet (exception - see [Lancache Rootful Security](#lancache-rootful-security))
  - Services: lancache/monolithic (nginx-based game download cache)
  - Priority: Low (cpu_units: 512)
  - Purpose: LAN cache for Steam, Epic, Battle.net game downloads
  - Storage: NFS-backed cache at /mnt/lancache (2TB limit, stored on NAS)
  - Deployment: Phase 3 (services)

#### Network Infrastructure

- **UniFi Controller** (VMID 800)
  - Resources: 2 cores, 2GB RAM, 32GB disk
  - IP: 192.168.0.19
  - Stack: Rootless Podman with Quadlet (MongoDB 7.0 + LinuxServer UniFi app)
  - Services: UniFi Network Application (AP and network device management)
  - Priority: Low (cpu_units: 512)
  - Purpose: Self-hosted UniFi Network Controller for managing APs and network devices
  - Deployment: Phase 3 (services)

### 3. Application Layer

**Home Assistant**: Podman Quadlet container for home automation and device integration

**Satisfactory**: Dedicated game server via SteamCMD, managed by systemd

**Jellyfin**: Native package with hardware transcoding via GPU passthrough:

- GTX 1080 GPU passthrough for NVENC hardware transcoding
- 32GB RAM disk for transcoding cache (zero SSD wear)
- 4 cores for non-GPU tasks
- CPU governor set to performance mode
- High scheduling priority (Nice=-10, realtime IO)

**Media Stack**: Rootless Podman with Quadlet systemd services:

- Sonarr/Radarr: Media management with Trash Guides folder structure
- Prowlarr: Indexer management
- Jellyseerr: Request management
- Bazarr: Subtitle automation
- Huntarr: Missing content discovery
- Homarr: Dashboard for service overview
- Byparr: Cloudflare bypass
- Recyclarr: Custom formats and quality profiles

**Download Clients**: Rootless Podman with Quadlet systemd services:

- Gluetun: VPN client (Private Internet Access with automatic port forwarding)
- qBittorrent: Torrent downloads (routed through VPN)
- SABnzbd: Usenet downloads with templated configuration (direct connection, no VPN)
- Unpackerr: Automatic archive extraction

**Tdarr**: Automated media transcoding and optimization:

- Transcodes media to space-efficient formats
- Runs on Jellyfin VM alongside media server
- Quadlet-based deployment

**NAS Services**: Storage, DNS, and container infrastructure:

- Btrfs RAID1: 3x 6TB disks in RAID1 (~9TB usable)
- NFS Server: Network file storage for media and downloads
- AdGuard Home: Network-wide DNS ad blocking and privacy protection
  - Deployment: Quadlet container on NAS VM
  - Upstream DNS: Quad9 DoT, Cloudflare DoT (encrypted)
  - MagicDNS Integration: Forwards `*.ts.net` queries to Tailscale (100.100.100.100)
  - Features: Ad blocking, query logging, custom filtering, DNSSEC validation
  - Web UI: http://nas.discus-moth.ts.net:80
- Nexus Repository: Container registry and artifact proxy
  - Deployment: Quadlet container on NAS VM
  - Purpose: Cache container images for CI/CD pipelines, reduce external pulls
  - Web UI: http://nas.discus-moth.ts.net:8081
  - Container Registry: nas.discus-moth.ts.net:5001

## Key Design Patterns

### CPU Allocation Strategy

**Total**: 16 physical cores / 32 threads (AMD EPYC 7313P)

The EPYC 7313P has 4 CCDs (Core Complex Dies), each with 4 cores sharing 32 MB L3 cache.
See [reference/epyc-7313p-optimization.md](reference/epyc-7313p-optimization.md) for detailed tuning.

**CCD-Aware Core Allocation:**

| CCD | Cores | L3 Cache | Allocation | Purpose |
|-----|-------|----------|------------|---------|
| CCD 0 | 0-3 | 32 MB | Reserved | Future Minecraft server |
| CCD 1 | 4-7 | 32 MB | **Pinned** | Satisfactory game server |
| CCD 2 | 8-11 | 32 MB | Shared pool | All other VMs |
| CCD 3 | 12-15 | 32 MB | Shared pool | All other VMs |

**Shared Pool (Cores 8-15)**:

- 8 physical cores shared across ~18 virtual cores (~2.25:1 overcommit)
- Overprovisioning is safe because workloads are bursty

**Priority Tiers** (cpu_units):

1. **High (2048)**: Satisfactory (pinned), Jellyfin (GPU handles transcoding)
2. **Medium (1024)**: Media Services, Download Clients, NAS, Monitoring, Home Assistant
3. **Low (512)**: Woodpecker CI

### Storage Architecture

- **VM Disks**: Local-lvm storage on Proxmox
- **Media/Downloads**: NFS mounted at `/mnt/data` (from NAS export `nas:/mnt/storage/data`)
- **NAS**: Passthrough disks for Btrfs RAID1 pool with snapshots
- **Folder Structure**: Trash Guides recommended layout for hardlinks

### Networking

**Local Network**: 192.168.0.0/24

- Gateway: 192.168.0.1
- DNS: AdGuard Home on NAS (192.168.0.15) via Tailscale custom nameserver
- Bridge: vmbr0 on Proxmox

**DNS Architecture**:

- **Primary DNS**: AdGuard Home (NAS VM, 192.168.0.15)
- **Upstream Resolvers**:
  1. Tailscale MagicDNS (100.100.100.100) for `*.ts.net` domains
  2. Quad9 DoT (tls://dns.quad9.net) - encrypted DNS
  3. Cloudflare DoT (tls://1dot1dot1dot1.cloudflare-dns.com) - encrypted DNS
  4. Quad9 plaintext fallback (9.9.9.11, 149.112.112.11)
- **Features**: Network-wide ad blocking, encrypted DNS queries, DNSSEC, query logging
- **Deployment**: Phase 2 (networking) - see [configuration/adguard-home.md](configuration/adguard-home.md)

**Tailscale Mesh**: 100.64.0.0/10 (CGNAT range)

- Secure remote access to all services
- Ephemeral auth keys generated via API
- Auto-approval with ACLs (see [reference/tailscale-auto-approval.md](reference/tailscale-auto-approval.md))
- MagicDNS enabled for `*.discus-moth.ts.net` hostnames

**Security**:

- UFW firewall on all VMs
- SSH accessible from Tailscale + local network (LAN fallback for outages)
- Services accessible from both Tailscale and local network

### Podman Quadlet Architecture

**Philosophy**: Native systemd integration, rootless containers (with documented exceptions), separation of concerns

**Structure**:

| VM | Quadlet Location | Scope | Notes |
|----|------------------|-------|-------|
| Most VMs | `~/.config/containers/systemd/` | User (rootless) | Standard deployment |
| Lancache | `/etc/containers/systemd/` | System (rootful) | NFS compatibility - see [security docs](#lancache-rootful-security) |

**Standard rootless structure** (per-VM, in `~/.config/containers/systemd/`):

```text
# Media Services VM (~/.config/containers/systemd/)
sonarr.container
radarr.container
prowlarr.container
jellyseerr.container
bazarr.container
huntarr.container
homarr.container
byparr.container
recyclarr.container

# Download Clients VM (~/.config/containers/systemd/)
gluetun.container
qbittorrent.container
sabnzbd.container
unpackerr.container
```

**Benefits**:

- Native systemd service management (`systemctl --user`)
- Automatic dependency ordering via `After=` directives
- Rootless containers (enhanced security)
- Standard journald logging (`journalctl --user`)
- No Docker daemon required

### Cloud-Init Template

**Template**: VMID 9000 (Ubuntu cloud-init)

- SSH key-only authentication
- Ansible user with sudo privileges
- No passwords set (security)
- All VMs cloned from this template

### Authentication Flow

1. `setup.sh` generates SSH key pair (`~/.ssh/ansible_homelab`)
2. Proxmox API uses vault-encrypted password (ansible@pve or root@pam)
3. Cloud-init template configured with Ansible SSH public key
4. VMs cloned with SSH key inheritance
5. Tailscale installed with ephemeral auth keys via API
6. Password-less SSH + Tailscale mesh access

## Resource Allocation Summary

### CPU Allocation (16 Physical Cores)

| Cores | Allocation | Purpose |
|-------|------------|---------|
| 0-3 | Reserved (Pinned) | Future Minecraft server |
| 4-7 | Satisfactory (Pinned) | Game server - dedicated |
| 8-15 | Shared Pool | All other VMs (~2:1 overcommit) |

### VM Resources

| VM               | VMID | Cores  | RAM      | Disk    | Priority | CPU Units |
|------------------|------|--------|----------|---------|----------|-----------|
| Home Assistant   | 100  | 2      | 2GB      | 40GB    | Medium   | 1024      |
| Satisfactory     | 200  | 4*     | 8GB      | 60GB    | High     | 2048      |
| NAS              | 300  | 2      | 6GB      | 3x6TB** | Medium   | 1024      |
| Jellyfin         | 400  | 4      | 8GB      | 80GB    | High     | 2048      |
| Media Services   | 401  | 4      | 8GB      | 50GB    | Medium   | 1024      |
| Download Clients | 402  | 4      | 6GB      | 60GB    | Medium   | 1024      |
| Monitoring       | 500  | 2      | 4GB      | 64GB    | Medium   | 1024      |
| Woodpecker CI    | 600  | 2      | 8GB      | 32GB    | Low      | 512       |
| Lancache         | 700  | 2      | 4GB      | 32GB*** | Low      | 512       |
| UniFi Controller | 800  | 2      | 2GB      | 32GB    | Low      | 512       |
| **Total**        |      | **28** | **56GB** |         |          |           |

*Satisfactory cores are pinned to physical cores 4-7 (was 2-3)
**NAS has 3x 6TB drives in Btrfs RAID1 (~9TB usable)
***Lancache uses NFS-backed cache storage (2TB limit on NAS)

### Memory Allocation (128GB Total)

| Allocation | Size | Purpose |
|------------|------|---------|
| Proxmox Host | ~8GB | Hypervisor overhead |
| RAM Disk (tmpfs) | 32GB | Jellyfin/Tdarr transcoding cache |
| Huge Pages (optional) | 8GB | VM memory optimization (disabled by default) |
| VMs Total | ~46GB | Allocated to virtual machines |
| Reserve | ~34GB | Headroom for bursts and future services |

**Note:** Huge pages are disabled by default. Enable in `proxmox_host` role for reduced TLB misses.
See [reference/epyc-7313p-optimization.md](reference/epyc-7313p-optimization.md) for configuration.

### GPU Allocation

| Component | Allocation |
|-----------|------------|
| GTX 1080 | Passthrough to Jellyfin VM (VMID 400) |
| Usage | NVENC hardware transcoding for Jellyfin and Tdarr |

**Monitoring VM (Phase 5) and Woodpecker CI (Phase C) are optional

## Design Decisions

### Why Separate Download Clients VM?

- **Resource Isolation**: Downloads don't impact media management
- **Priority Control**: Medium priority vs low priority media stack
- **Fault Isolation**: Download client issues don't affect Sonarr/Radarr
- **Network Isolation**: Easier to implement VPN if needed in future

### Why Native Jellyfin (Not Containerized)?

- **Direct Hardware Access**: Better transcoding performance
- **System Integration**: CPU governor, systemd priority settings
- **Resource Control**: Full control over process scheduling
- **Easier Updates**: Standard apt package management

### Why Podman Quadlet (Not Docker Compose)?

- **Rootless Security**: Containers run without root privileges
- **Systemd Integration**: Native service management, journald logging
- **No Daemon**: No background Docker daemon required
- **Per-Service Control**: Each container is an independent systemd unit
- **Declarative**: `.container` files define container configuration

### Why Overprovisioned CPUs?

- **Workload Characteristics**: Bursty, not sustained
- **Priority System**: cpu_units ensure important VMs get cycles
- **Cost Efficiency**: Maximize hardware utilization
- **Real Usage**: Most VMs idle most of the time

## Network Diagram

```text
┌──────────────────────────────────────────────────────────────────┐
│ Proxmox Host (discus-moth.ts.net)                                │
│ EPYC 7313P: 16 cores/32 threads, 128GB RAM                       │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐       │
│  │ Home         │  │ Satisfactory  │  │ NAS             │       │
│  │ Assistant    │  │ (pinned 4-7)  │  │ Btrfs RAID1     │       │
│  │ .10          │  │ .11           │  │ NFS + AdGuard   │       │
│  └──────────────┘  └───────────────┘  │ .15 (DNS)       │       │
│                                        └─────────────────┘       │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐       │
│  │ Jellyfin     │  │ Media         │  │ Download        │       │
│  │ (4 cores)    │  │ Services      │  │ Clients         │       │
│  │ .12          │  │ .13           │  │ .14             │       │
│  └──────────────┘  └───────────────┘  └─────────────────┘       │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐       │
│  │ Monitoring   │  │ Woodpecker CI │  │ Lancache        │       │
│  │ Prometheus   │  │ CI/CD Server  │  │ Game DL Cache   │       │
│  │ .16          │  │ .17           │  │ .18             │       │
│  └──────────────┘  └───────────────┘  └─────────────────┘       │
│                                                                  │
│  ┌──────────────┐                                                │
│  │ UniFi        │                                                │
│  │ Controller   │                                                │
│  │ .19          │                                                │
│  └──────────────┘                                                │
│                                                                  │
│  vmbr0 Bridge ─────────────┬─────── 192.168.0.0/24               │
└────────────────────────────┼─────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │ Gateway/Router  │
                    │  192.168.0.1    │
                    └─────────────────┘
                             │
                          Internet
                             │
                    ┌────────┴────────┐
                    │   Tailscale     │
                    │   Mesh VPN      │
                    │ + MagicDNS      │
                    └────┬────────────┘
                         │
                    Custom DNS: NAS
                    (AdGuard Home)
```

## Lancache Rootful Security

Lancache is the **only service** running as rootful Podman rather than the standard rootless deployment.
This is an intentional exception due to technical requirements with NFS storage.

### Why Rootful is Required

1. The lancache container runs its nginx process as `www-data` (UID 33)
2. Container startup scripts execute `chown("/data/cache/cache", 33)` to claim the cache directory
3. With rootless Podman, container UID 0 maps to the host's `ansible` user via user namespaces
4. NFS sees this as a non-root user attempting to chown → **permission denied**
5. `no_root_squash` doesn't help because rootless "root" is just a mapped user, not actual root

With rootful Podman:

- Container UID 0 = Host UID 0 (actual root)
- Container UID 33 (www-data) = Host UID 33
- NFS sees real root doing chown operations
- Existing `no_root_squash` on NFS export works correctly

### Security Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Container escape = root access | Isolated VM with no sensitive data; lancache only caches game downloads |
| Host network mode | Required for lancache anyway; ports 80/443 bound only on local network |
| no_root_squash on NFS | Limited to single client IP (192.168.0.18/32) |
| NFS privilege escalation | Mount options include `nosuid,nodev` to prevent setuid/device attacks |
| Running as root | NOT `--privileged`; just runs as host root UID without extra capabilities |

### What Rootful Means

- Container UID 0 = Host UID 0 (actual root)
- No user namespace isolation between container and host
- systemd service runs at system level (`/etc/containers/systemd/`)
- Service managed with `sudo systemctl` (not `systemctl --user`)

### What Rootful Does NOT Mean

- Container is NOT running with `--privileged` flag
- Container does NOT have elevated capabilities (CAP_SYS_ADMIN, etc.)
- Container is NOT bypassing SELinux/AppArmor (if configured)
- Container does NOT have access to host devices

### Alternatives Considered (and rejected)

| Alternative | Why Rejected |
|-------------|--------------|
| Pre-create cache with UID 33 | Lancache recreates directory structure on every container start |
| Bind-mount with `:U` flag | Only works with local storage, not NFS |
| Use `all_squash` + `anonuid=33` | Would force all NFS operations to UID 33, affecting other services |
| Local storage instead of NFS | Loses the benefit of centralized cache on NAS |
| Fork lancache container | Upstream maintenance burden; fragile solution |

### Service Management

```bash
# System-level service (not --user)
sudo systemctl status lancache
sudo systemctl restart lancache
sudo journalctl -u lancache -f

# Container operations
sudo podman logs lancache
sudo podman exec -it lancache /bin/bash
```

## See Also

- [AdGuard Home Configuration](configuration/adguard-home.md) - DNS setup and management
- [EPYC 7313P Optimization](reference/epyc-7313p-optimization.md) - CPU tuning and BIOS settings
- [Resource Allocation Details](configuration/resource-allocation.md)
- [Networking Configuration](configuration/networking.md)
- [Playbooks Reference](reference/playbooks.md)
