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
  - IP: 192.168.20.10 (IoT VLAN 20)
  - Stack: Rootless Podman with Quadlet
  - Priority: Medium (cpu_units: 1024)

#### Game Servers

- **Satisfactory** (VMID 200)
  - Resources: 4 cores (pinned 4-7), 8GB RAM, 60GB disk
  - IP: 192.168.40.11 (Games VLAN 40)
  - Stack: SteamCMD + systemd service
  - Priority: High (cpu_units: 2048, dedicated cores)
  - Note: Cores 0-3 reserved for future Minecraft server

- **Mumble** (VMID 201)
  - Resources: 1 core, 1GB RAM, 32GB disk
  - IP: 192.168.40.20 (Games VLAN 40)
  - Stack: Rootless Podman with Quadlet
  - Services: Mumble voice chat server (mumblevoip/mumble-server)
  - Priority: Low (cpu_units: 512)
  - Deployment: Phase 4 (optional)

#### Storage Infrastructure

- **NAS** (VMID 300)
  - Resources: 2 cores, 6GB RAM, 32GB OS disk + 3x 6TB passthrough (Btrfs RAID1)
  - IP: 192.168.30.15 (Media VLAN 30)
  - Stack: Btrfs RAID1 (~9TB usable), NFS server, AdGuard Home, Nexus Repository (Quadlet)
  - Services: NFS, AdGuard Home (DNS), Nexus Repository (container registry)
  - Priority: Medium (cpu_units: 1024)
  - Purpose: Network storage, internal DNS with ad blocking, container image caching

- **DB** (VMID 301)
  - Resources: 2 cores, 4GB RAM, 64GB disk
  - IP: 192.168.30.16 (Media VLAN 30)
  - Stack: Native Ubuntu PostgreSQL 16 (not containerized)
  - Databases: sonarr_main/log, radarr_main/log, lidarr_main/log, prowlarr_main/log, bazarr_main, synapse
  - Per-service DB users; shared password from SOPS vault
  - Purpose: Centralized database for all k3s media/matrix services

#### Monitoring Infrastructure

- **Monitoring** (VMID 500)
  - Resources: 2 cores, 4GB RAM, 64GB disk
  - IP: 192.168.10.16 (Management VLAN 10)
  - Stack: Rootless Podman with Quadlet
  - Services: Prometheus, Alertmanager, Grafana, SNMP Exporter, Blackbox Exporter
  - Priority: Medium (cpu_units: 1024)
  - Purpose: Internal infrastructure monitoring with Discord alerting
  - Deployment: Phase 5 (optional, standalone)
  - Note: Uptime Kuma moved to external monitoring (Oracle Cloud)

#### CI/CD Infrastructure

- **Woodpecker CI** (VMID 600)
  - Resources: 2 cores, 8GB RAM, 32GB disk
  - IP: 192.168.10.17 (Management VLAN 10)
  - Stack: Rootless Podman with Quadlet
  - Services: Woodpecker Server, Woodpecker Agent
  - Priority: Low (cpu_units: 512)
  - Purpose: Automated testing, linting, security scanning, and deployment pipelines
  - Deployment: Phase 2 (CI infrastructure)

#### Caching Infrastructure

- **Lancache** (VMID 700)
  - Resources: 2 cores, 4GB RAM, 32GB disk + NFS cache storage
  - IP: 192.168.40.18 (Games VLAN 40)
  - Stack: **Rootful Podman** with Quadlet (exception - see [Lancache Rootful Security](#lancache-rootful-security))
  - Services: lancache/monolithic (nginx-based game download cache)
  - Priority: Low (cpu_units: 512)
  - Purpose: LAN cache for Steam, Epic, Battle.net game downloads
  - Storage: NFS-backed cache at /mnt/lancache (2TB limit, stored on NAS)
  - Deployment: Phase 3 (services)

#### Network Infrastructure

- **UniFi Controller** (VMID 800)
  - Resources: 2 cores, 2GB RAM, 32GB disk
  - IP: 192.168.10.19 (Management VLAN 10)
  - Stack: Rootless Podman with Quadlet (MongoDB 7.0 + LinuxServer UniFi app)
  - Services: UniFi Network Application (AP and network device management)
  - Priority: Low (cpu_units: 512)
  - Purpose: Self-hosted UniFi Network Controller for managing APs and network devices
  - Deployment: Phase 3 (services)

### 3. k3s Cluster

5-node k3s cluster on Media VLAN (192.168.30.x). Flux GitOps manages all workloads via `jellybuntu-helm` repo.

#### Cluster Nodes

| Node | IP | Role label | Workloads |
|------|----|------------|-----------|
| k8s-control | 192.168.30.40 | — | Control plane only |
| k8s-gpu | 192.168.30.41 | gpu | Jellyfin, Tdarr |
| k8s-media | 192.168.30.42 | media | *arr stack, download clients, Navidrome, Jellyseerr, Byparr, Recyclarr, Unpackerr |
| k8s-net | 192.168.30.43 | net | Traefik ingress |
| k8s-ops | 192.168.30.44 | ops | Synapse, LiveKit, Coturn, lk-jwt, synapse-admin, TeamSpeak |

Node selector label key: `jellybuntu.io/role`

#### Namespaces

| Namespace | Node label | Services |
|-----------|------------|---------|
| media | media | sonarr, radarr, lidarr, prowlarr, bazarr, navidrome, jellyseerr, byparr, qbittorrent, sabnzbd, recyclarr, unpackerr |
| gpu | gpu | jellyfin, tdarr |
| matrix | ops | synapse, livekit, coturn, lk-jwt, synapse-admin |
| teamspeak | ops | teamspeak |
| traefik-system | net | traefik |
| metallb-system | — | metallb |
| nfs-system | — | nfs-subdir-provisioner |

#### GitOps

- Helm charts: [`SilverDFlame/jellybuntu-helm`](https://github.com/SilverDFlame/jellybuntu-helm) (`main` branch, protected)
- Flux polls every 1 min, reconciles every 10 min
- Kustomization chain: `infrastructure` → `media`, `gpu`, `net`, `ops`
- All workloads use `bjw-s/app-template` 4.6.x OCI chart
- Secrets: SOPS + age (same vault as Ansible)

Force reconcile after helm PR merges:

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization infrastructure -n flux-system
```

#### Networking

- MetalLB pool: `192.168.30.200/29` (L2 mode, .200–.207)
- Traefik on k8s-net, `LoadBalancer` service, `externalTrafficPolicy: Local`
- All services: `*.elysium.industries` (Let's Encrypt + Cloudflare DNS-01)
- IP allowlist middleware (admin tools): `192.168.30.0/24`, `100.64.0.0/10`

#### Storage

| Type | Details |
|------|---------|
| Config PVCs | `nfs-client` storage class — NFS subdir dynamic provisioner |
| Media library | Static PV `nfs-media` → `192.168.30.15:/mnt/storage/data` (1Ti, RWMany) |
| Media library (gpu ns) | Static PV `nfs-media-gpu` → same path (namespace isolation) |
| Transcode cache | hostPath on k8s-gpu: `/mnt/transcode-cache/{jellyfin,tdarr}` |

#### GPU

- k8s-gpu: GTX 1080 PCIe passthrough
- NVIDIA device plugin time-slices 1 GPU → 2 virtual (Jellyfin + Tdarr co-schedule)

### 4. Application Layer

**Home Assistant**: Podman Quadlet container for home automation and device integration

**Satisfactory**: Dedicated game server via SteamCMD, managed by systemd

**Jellyfin** (k3s, gpu namespace):

- GTX 1080 GPU passthrough via NVIDIA device plugin
- hostPath transcode cache on k8s-gpu
- Hardware NVENC transcoding

**Media Stack** (k3s, media namespace): Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, Navidrome, Jellyseerr, Byparr, Recyclarr

**Download Clients** (k3s, media namespace): qBittorrent, SABnzbd, Unpackerr

**Tdarr** (k3s, gpu namespace): Automated media transcoding; shares GPU time-slice with Jellyfin

**Matrix/Synapse** (k3s, matrix namespace):

- Synapse homeserver with PostgreSQL 16 backend (db VM)
- LiveKit SFU for Element Call voice/video (WebRTC)
- lk-jwt-service for MatrixRTC authorization bridge
- coturn TURN/STUN server
- Synapse Admin web UI
- Registration disabled; users onboarded via registration tokens
- Federation disabled (internal use only)

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

1. **High (2048)**: Satisfactory (pinned)
2. **Medium (1024)**: NAS, Monitoring, Home Assistant, DB
3. **Low (512)**: Woodpecker CI, Mumble, Lancache, UniFi Controller

### Storage Architecture

- **VM Disks**: Local-lvm storage on Proxmox
- **Media/Downloads**: NFS mounted from NAS (`192.168.30.15:/mnt/storage/data`)
- **k3s config PVCs**: NFS subdir dynamic provisioner (`nfs-client` storage class)
- **NAS**: Passthrough disks for Btrfs RAID1 pool with snapshots
- **Folder Structure**: Trash Guides recommended layout for hardlinks

### Networking

**VLAN Architecture**: Segmented network via VLAN-aware bridge on Proxmox

| VLAN | Subnet | Purpose | Gateway |
|------|--------|---------|---------|
| VLAN 10 | 192.168.10.0/24 | Management | 192.168.10.1 |
| VLAN 20 | 192.168.20.0/24 | IoT | 192.168.20.1 |
| VLAN 30 | 192.168.30.0/24 | Media + k3s cluster | 192.168.30.1 |
| VLAN 40 | 192.168.40.0/24 | Games | 192.168.40.1 |

- DNS: AdGuard Home on NAS (192.168.30.15) via Tailscale custom nameserver
- Bridge: vmbr0 (VLAN-aware) on Proxmox

**DNS Architecture**:

- **Primary DNS**: AdGuard Home (NAS VM, 192.168.30.15)
- **Upstream Resolvers**:
  1. Tailscale MagicDNS (100.100.100.100) for `*.ts.net` domains
  2. Quad9 DoT (tls://dns.quad9.net) - encrypted DNS
  3. Cloudflare DoT (tls://1dot1dot1dot1.cloudflare-dns.com) - encrypted DNS
  4. Quad9 plaintext fallback (9.9.9.11, 149.112.112.11)
- **Features**: Network-wide ad blocking, encrypted DNS queries, DNSSEC, query logging
- **Deployment**: Phase 2 (networking) - see [configuration/adguard-home.md](configuration/adguard-home.md)

**k3s Ingress**: Traefik on k8s-net, MetalLB VIP from `192.168.30.200/29`. All `*.elysium.industries` routes via Let's Encrypt + Cloudflare DNS-01.

**Tailscale Mesh**: 100.64.0.0/10 (CGNAT range)

- Secure remote access to all services
- Ephemeral auth keys generated via API
- Auto-approval with ACLs (see [reference/tailscale-auto-approval.md](reference/tailscale-auto-approval.md))
- MagicDNS enabled for `*.discus-moth.ts.net` hostnames
- k8s-net advertises `192.168.30.200/29` as Tailscale subnet route

**Security**:

- UFW firewall on all standalone VMs
- SSH accessible from Tailscale + Management VLAN 10 (LAN fallback for outages)
- k3s admin tools restricted by IP allowlist middleware: `192.168.30.0/24`, `100.64.0.0/10`

### Podman Quadlet Architecture

**Philosophy**: Native systemd integration, rootless containers (with documented exceptions), separation of concerns

**Structure**:

| VM | Quadlet Location | Scope | Notes |
|----|------------------|-------|-------|
| Most VMs | `~/.config/containers/systemd/` | User (rootless) | Standard deployment |
| Lancache | `/etc/containers/systemd/` | System (rootful) | NFS compatibility - see [security docs](#lancache-rootful-security) |

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

### VM Resources (Standalone)

| VM               | VMID | Cores  | RAM      | Disk    | Priority | CPU Units |
|------------------|------|--------|----------|---------|----------|-----------|
| Home Assistant   | 100  | 2      | 2GB      | 40GB    | Medium   | 1024      |
| Satisfactory     | 200  | 4*     | 8GB      | 60GB    | High     | 2048      |
| Mumble           | 201  | 1      | 1GB      | 32GB    | Low      | 512       |
| NAS              | 300  | 2      | 6GB      | 3x6TB** | Medium   | 1024      |
| DB               | 301  | 2      | 4GB      | 64GB    | Medium   | 1024      |
| Monitoring       | 500  | 2      | 4GB      | 64GB    | Medium   | 1024      |
| Woodpecker CI    | 600  | 2      | 8GB      | 32GB    | Low      | 512       |
| Lancache         | 700  | 2      | 4GB      | 32GB*** | Low      | 512       |
| UniFi Controller | 800  | 2      | 2GB      | 32GB    | Low      | 512       |

*Satisfactory cores are pinned to physical cores 4-7
**NAS has 3x 6TB drives in Btrfs RAID1 (~9TB usable)
***Lancache uses NFS-backed cache storage (2TB limit on NAS)

### k3s Cluster Nodes

| Node | IP | vCPUs | RAM | Disk |
|------|----|-------|-----|------|
| k8s-control | 192.168.30.40 | 2 | 4GB | 32GB |
| k8s-gpu | 192.168.30.41 | 4 | 16GB | 80GB + GTX 1080 |
| k8s-media | 192.168.30.42 | 4 | 10GB | 50GB |
| k8s-net | 192.168.30.43 | 2 | 2GB | 32GB |
| k8s-ops | 192.168.30.44 | 4 | 8GB | 64GB |

### Memory Allocation (128GB Total)

| Allocation | Size | Purpose |
|------------|------|---------|
| Proxmox Host | ~8GB | Hypervisor overhead |
| RAM Disk (tmpfs) | 32GB | Transcoding cache (k8s-gpu hostPath) |
| Huge Pages (optional) | 8GB | VM memory optimization (disabled by default) |
| Standalone VMs | ~37GB | Allocated to standalone virtual machines |
| k3s Nodes | ~40GB | Allocated to k3s cluster nodes |
| Reserve | ~3GB | Headroom for bursts |

**Note:** Huge pages are disabled by default. Enable in `proxmox_host` role for reduced TLB misses.
See [reference/epyc-7313p-optimization.md](reference/epyc-7313p-optimization.md) for configuration.

### GPU Allocation

| Component | Allocation |
|-----------|------------|
| GTX 1080 | PCIe passthrough to k8s-gpu node |
| Usage | NVENC hardware transcoding — time-sliced 1 GPU → 2 virtual (Jellyfin + Tdarr) |

## Design Decisions

### Why k3s Instead of Standalone VMs for Media Stack?

- **Resource Efficiency**: Shared cluster overhead vs per-VM OS costs
- **Scheduling**: Kubernetes node selectors pin workloads to appropriate hardware
- **GitOps**: Flux + Helm provides declarative, auditable service management
- **Scalability**: Add nodes without reprovisioning all services

### Why Separate Download Clients VM? (historical)

Download clients now run in k3s media namespace. The separate VM approach (isolation, VPN routing) is preserved via Kubernetes NetworkPolicy and Gluetun sidecar pattern.

### Why Native PostgreSQL (DB VM)?

- **Stability**: Single PostgreSQL 16 instance for all services
- **Performance**: Direct disk access, no container overhead
- **Simplicity**: One backup target, one connection string pattern

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
┌──────────────────────────────────────────────────────────────────────┐
│ Proxmox Host (discus-moth.ts.net)                                    │
│ EPYC 7313P: 16 cores/32 threads, 128GB RAM                           │
│ Bridge: vmbr0 (VLAN-aware)                                           │
│                                                                      │
│  ┌─ Management VLAN 10 ────────────────────────────────────────────┐ │
│  │ Monitoring (.16)  Woodpecker (.17)  UniFi (.19)                 │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─ IoT VLAN 20 ──────────┐                                         │
│  │ Home Assistant (.10)    │                                         │
│  └─────────────────────────┘                                         │
│                                                                      │
│  ┌─ Media VLAN 30 ─────────────────────────────────────────────────┐ │
│  │ NAS (.15)  DB (.16)                                             │ │
│  │ k8s-control (.40)  k8s-gpu (.41)  k8s-media (.42)              │ │
│  │ k8s-net (.43)  k8s-ops (.44)                                    │ │
│  │ MetalLB VIP pool: .200-.207                                     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─ Games VLAN 40 ─────────────────────────────────────────────────┐ │
│  │ Satisfactory (.11)  Mumble (.20)  Lancache (.18)                │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                         │
                ┌────────┴────────┐
                │ Gateway/Router  │
                │ (per-VLAN .1)   │
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
| no_root_squash on NFS | Limited to single client IP (192.168.40.18/32) |
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
