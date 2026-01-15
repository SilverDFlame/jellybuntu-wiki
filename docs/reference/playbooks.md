# Playbooks Reference

Complete reference for all Ansible playbooks in the Jellybuntu infrastructure.

## Overview

The infrastructure uses **phase-based deployment** with **modular, role-based playbooks**. Playbooks are numbered 00-20
(00-14 for core infrastructure, 15-19 for advanced/optional services, 20 for container registry in Phase 2) and use
the `-role` suffix to indicate they leverage reusable roles.

## Deployment Approaches

### Phase-Based (Recommended)

Run complete phases in order for organized deployment:

```bash
# Phase 1: Infrastructure
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml

# Phase 2: Networking
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml

# Phase 3: Services
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml

# Phase 4: Post-Deployment (after manual GUI configuration)
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml

# Phase 5: Monitoring (optional, can run independently after Phase 2)
./bin/runtime/ansible-run.sh playbooks/phases/phase5-monitoring.yml
```

### Individual Playbooks

Run specific playbooks for targeted updates:

```bash
./bin/runtime/ansible-run.sh playbooks/core/06-configure-media-services-role.yml
```

### Complete Deployment

Run all phases at once (skips Phase 4):

```bash
./bin/runtime/ansible-run.sh playbooks/main.yml
```

## Phase Playbooks

### phase1-infrastructure.yml

**Includes**: 01-provision-vms.yml

**Purpose**: Provision all VMs on Proxmox

**What It Does**:

- Creates cloud-init template (VMID 9000)
- Provisions all 6 VMs with configured resources
- Sets static IPs and network configuration
- Configures CPU pinning and priorities

**Duration**: ~10 minutes

---

### phase2-networking.yml

**Includes**: 00, 02, 03, 12, 20

**Purpose**: Configure storage, networking, and container registry

**What It Does**:

- Configures SSH authorized keys (playbook 00)
- Configures Btrfs NAS with RAID1 and NFS server (playbook 02)
- Installs Tailscale VPN on all VMs (playbook 03)
- Deploys Nexus container registry on NAS (playbook 20) - required before Phase 3
- Deploys AdGuard Home DNS on NAS (playbook 12)
- Sets up automated snapshots and maintenance on NAS

**Duration**: ~10 minutes

**Note**: NAS becomes available at `nas.discus-moth.ts.net` or `192.168.0.15`
**Container Registry**: Nexus at nas.discus-moth.ts.net:5001 (required for Phase 3 services)
**DNS**: AdGuard Home provides network-wide ad blocking at http://nas.discus-moth.ts.net:80

---

### phase3-services.yml

**Includes**: 09, 04-07, 10 (NFS mounts first, then services)

**Purpose**: Deploy all applications and services

**What It Does**:

- Home Assistant (04)
- Satisfactory game server (05)
- Media services stack: Sonarr, Radarr, Prowlarr, Jellyseerr, FlareSolverr (06)
- Download clients: qBittorrent, SABnzbd (07)
- NFS client mounts on service VMs (09)
- Jellyfin with transcoding optimizations (10)

**Duration**: ~15 minutes

**After This Phase**: Services are deployed but need manual GUI configuration (see post-deployment.md)

---

### phase4-post-deployment.yml

**Includes**: 08, 11

**Purpose**: Final configuration and security hardening

**What It Does**:

- Recyclarr sync with API keys from vault (08)
- System hardening - UFW firewall + unattended-upgrades (11)

**Duration**: ~3 minutes

**Note**: SSH remains accessible via both Tailscale hostnames and local network IPs (LAN fallback).

**Prerequisites**:

- Manual GUI configuration completed
- API keys added to secrets file

---

### phase5-monitoring.yml

**Includes**: 13, 14

**Purpose**: Deploy comprehensive infrastructure monitoring (optional)

**What It Does**:

- Deploys node_exporter on all VMs and Proxmox host (13)
- Deploys cAdvisor on Podman VMs for container metrics (13)
- Configures Prometheus for metrics collection (14)
- Deploys Grafana with pre-configured dashboards (14)
- Sets up Uptime Kuma for service monitoring and alerting (14)

**Duration**: ~15-30 minutes

**Prerequisites**:

- Phase 2 completed (Tailscale networking required)
- Phase 3 recommended but not required (for Podman container monitoring)
- **Monitoring VM**: Use OpenTofu for provisioning (VMID 500, 4 cores, 6GB RAM, 192.168.0.16)

**Notes**:

- This phase is **optional** and can be deployed independently
- Can run anytime after Phase 2 (Tailscale networking)
- Monitoring VM provisioning moved to OpenTofu (see Infrastructure section)
- Uses Podman Compose (not Docker) for isolation from other services

---

## Individual Playbooks

### 01-provision-vms.yml

**Target**: Proxmox host
**Role**: Uses Proxmox modules directly

**Creates**:

- Cloud-init template (VMID 9000)
- Home Assistant VM (VMID 100)
- Satisfactory VM (VMID 200) - with CPU pinning
- NAS VM (VMID 300)
- Jellyfin VM (VMID 400)
- Media Services VM (VMID 401)
- Download Clients VM (VMID 402)

**Variables**: [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml)

---

### 02-configure-nas-role.yml

**Target**: nas (192.168.0.15)
**Roles**: btrfs_storage, nfs_server, btrfs_snapshots, btrfs_maintenance

**Creates**:

- Btrfs RAID1 filesystem on /dev/sdb + /dev/sdc
- NFS server exporting `/mnt/storage/data`
- Automated daily/weekly/monthly snapshots
- Weekly scrub maintenance

**Folder Structure Created**:

```text
/mnt/storage/
├── @data/
│   ├── media/tv/
│   ├── media/movies/
│   ├── torrents/{tv,movies,incomplete}/
│   └── usenet/{tv,movies,incomplete}/
└── @snapshots/@data/
```

---

### 03-configure-tailscale-role.yml

**Target**: All Ubuntu VMs
**Role**: tailscale

**Installs**: Tailscale VPN on all VMs
**Network**: 100.64.0.0/10 (CGNAT range)
**Hostnames**: `*.discus-moth.ts.net`

---

### 04-configure-home-assistant-role.yml

**Target**: home_assistant
**Roles**: docker, docker_compose_app

**Service**: Home Assistant in Docker
**Port**: 8123
**URL**: http://home-assistant.discus-moth.ts.net:8123

---

### 05-configure-satisfactory-role.yml

**Target**: satisfactory_server
**Role**: Custom tasks (SteamCMD)

**Service**: Satisfactory Dedicated Server
**Ports**: 7777 (game), 15000 (beacon), 15777 (query)
**CPU**: Pinned to cores 2-3 for consistent performance

---

### 06-configure-media-services-role.yml

**Target**: media_services
**Roles**: docker, nfs_client, docker_compose_app

**Services Deployed**:

- Sonarr (8989) - TV show management
- Radarr (7878) - Movie management
- Prowlarr (9696) - Indexer management
- Jellyseerr (5055) - Media request management
- Bazarr (6767) - Subtitle automation
- Huntarr (9705) - Missing content discovery
- Flaresolverr (8191) - Cloudflare bypass
- Recyclarr - TRaSH Guides quality profiles sync
- Homarr - Application dashboard

**Config**: Uses modular compose files in [`services/compose/services/`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/services/)

---

### 07-configure-download-clients-role.yml

**Target**: download_clients
**Roles**: docker, nfs_client, docker_compose_app

**Services Deployed**:

- Gluetun - VPN client (Private Internet Access with automatic port forwarding)
- qBittorrent (8080) - Torrent downloads routed through VPN
- SABnzbd (8081) - Usenet downloads (direct connection, no VPN)
- Unpackerr - Automatic archive extraction

**Key Features**:

- Isolated VM for resource management
- VPN protection for torrent traffic via PIA with automatic port forwarding
- SABnzbd configured with hostname whitelist and local_ranges
- qBittorrent automated configuration via Web API
- Port forwarding automation with systemd service (pia-port-sync)
- Categories pre-configured (tv, movies)
- Unpackerr integration for automatic extraction

---

### 08-configure-recyclarr-role.yml

**Target**: media_services
**Role**: podman_app

**Service**: Recyclarr (TRaSH Guides sync)
**Purpose**: Apply custom formats and quality profiles

**Requires**: Sonarr/Radarr API keys in secrets file

---

### 09-configure-nfs-clients-role.yml

**Target**: jellyfin, media_services, download_clients
**Role**: nfs_client

**Mounts**: `/mnt/data` from `nas.discus-moth.ts.net:/mnt/storage/data`
**Permissions**: UID/GID 3000 (nfsuser)

---

### 10-configure-jellyfin-role.yml

**Target**: jellyfin
**Roles**: Custom tasks, nfs_client

**Service**: Jellyfin (native package, not Docker)
**Port**: 8096 (HTTP), 8920 (HTTPS)
**URL**: http://jellyfin.discus-moth.ts.net:8096

**Optimizations**:

- 4 cores for parallel transcoding
- CPU governor: performance
- High scheduling priority (Nice=-10)
- AES CPU flags enabled
- System limits configured

---

### 11-configure-system-hardening-role.yml

**Target**: All Ubuntu VMs (production_vms)
**Roles**: ufw_firewall, unattended_upgrades

**Configures**:

- UFW firewall (SSH from Tailscale + local network)
- Service ports open to local network (192.168.0.0/24) + Tailscale
- Default deny incoming policy
- Automatic security update installation
- No auto-reboot (manual reboots for kernel updates)
- Automatic package cleanup

**Note**: SSH accessible via both Tailscale and LAN (fallback for Tailscale outages).

**Per-Host Rules**: Defined in [`host_vars/*.yml`](https://github.com/SilverDFlame/jellybuntu/tree/main/host_vars) via `firewall_ports`

---

### 12-configure-adguard-home-role.yml

**Target**: nas (192.168.0.15)
**Roles**: adguard_home

**Service**: AdGuard Home (Docker)
**Ports**: 53 (DNS), 80 (Web UI)
**URL**: http://nas.discus-moth.ts.net:80

**Features**:

- Network-wide DNS ad blocking and filtering
- Local Unbound recursive resolver (primary upstream)
- DoT fallback to Quad9/Cloudflare (if Unbound fails)
- Tailscale MagicDNS integration (forwards `*.ts.net` queries to 100.100.100.100)
- Pre-configured comprehensive blocklists (10 lists, ~2.3M rules):
  - AdGuard DNS filter + AdAway (general ads/trackers)
  - OISD Big List (comprehensive blocking)
  - Hagezi Pro++ (advanced threats)
  - Steven Black Unified FGP (fake news, gambling, porn)
  - OISD NSFW + Hagezi Porn Ultimate (adult content)
  - Block List Project Porn/Malware
  - DandelionSprout Anti-Malware
- DNSSEC validation enabled (via Unbound)
- Auto-configured admin credentials from vault
- Automatic blocklist updates (24 hours)

**Configuration**:

- Disables systemd-resolved stub listener (prevents port 53 conflicts)
- Configures UFW firewall for DNS (port 53) and Web UI (port 80)
- Creates `/opt/adguard-home/` for configuration and data storage

**Post-Deployment**:

1. Access Web UI at http://nas.discus-moth.ts.net:80
2. Login with credentials from vault (`vault_services_admin_username` / `vault_services_admin_password`)
3. **Optional**: Configure Tailscale custom DNS nameserver (NAS Tailscale IP) for network-wide ad blocking
4. **Optional**: Deploy Unbound (playbook 16-configure-unbound-role.yml) in Phase C for recursive DNS

**Dependencies**: Unbound (playbook 16) is optional - AdGuard uses DoT fallback (Quad9/Cloudflare)
until Unbound is deployed in Phase C

---

### 13-deploy-monitoring-exporters.yml

**Target**: All VMs + Proxmox host
**Roles**: node_exporter, podman_app (cAdvisor)

**Purpose**: Deploy monitoring exporters across infrastructure

**What It Does**:

- Installs **node_exporter** (port 9100) on:
  - Proxmox host (system metrics)
  - All 7 guest VMs (system metrics)
- Installs **cAdvisor** (port 8180) on Docker VMs:
  - Media Services (401)
  - Download Clients (402)
  - Jellyfin (400) - if using Docker containers

**Exporters**:

- **node_exporter**: CPU, memory, disk, network metrics
- **cAdvisor**: Docker container metrics (CPU, memory, I/O)

**Firewall**:

- Opens port 9100 for node_exporter (Tailscale + local network)
- Opens port 8180 for cAdvisor (Tailscale + local network)

**Duration**: ~5-8 minutes

**Prerequisites**:

- Phase 2 completed (Tailscale networking)
- UFW firewall configured (if Phase 4 completed)

**Monitoring Targets**:

- Proxmox host: node_exporter only
- Guest VMs: node_exporter on all
- Docker VMs: node_exporter + cAdvisor

---

### 14-configure-monitoring-stack.yml

**Target**: monitoring (192.168.0.16)
**Roles**: podman_app

**Purpose**: Deploy Prometheus, Grafana, and Uptime Kuma

**Services Deployed**:

1. **Prometheus** (port 9090)
   - Metrics collection and storage
   - Scrapes all node_exporter and cAdvisor endpoints
   - 15-day retention (configurable)
   - Resource limits: 2GB RAM, 1.0 CPU

2. **Grafana** (port 3000)
   - Visualization and dashboards
   - Pre-configured Prometheus data source
   - Pre-imported dashboards:
     - Node Exporter Full (system metrics)
     - Podman Container Metrics (cAdvisor)
     - Proxmox Overview
   - Auto-configured admin credentials from vault
   - Resource limits: 1GB RAM, 0.5 CPU

3. **Uptime Kuma** (port 3001)
   - Service uptime monitoring
   - HTTP/HTTPS endpoint checks
   - Status page generation
   - Alert notifications (email, Discord, etc.)
   - Resource limits: 512MB RAM, 0.5 CPU

4. **SNMP Exporter** (port 9116)
   - Network device monitoring
   - Localhost only

5. **Blackbox Exporter** (port 9115)
   - Endpoint health checks
   - HTTP/HTTPS probing
   - Localhost only

**Stack**: Podman Compose (not Docker)

**Directory Structure**:

- `/opt/monitoring/` - Main directory
- `/opt/monitoring/data/prometheus` - Prometheus TSDB
- `/opt/monitoring/data/grafana` - Grafana dashboards/plugins
- `/opt/monitoring/data/uptime-kuma` - Uptime Kuma database
- `/opt/monitoring/config/` - Configuration files

**Access URLs**:

- Prometheus: http://monitoring.discus-moth.ts.net:9090
- Grafana: http://monitoring.discus-moth.ts.net:3000
- Uptime Kuma: http://monitoring.discus-moth.ts.net:3001

**Duration**: ~10-15 minutes

**Prerequisites**:

- Monitoring VM provisioned via OpenTofu (VMID 500)
- Playbook 13 completed (exporters deployed)
- Phase 2 completed (Tailscale networking)

**Post-Deployment**:

1. Access Grafana at http://monitoring.discus-moth.ts.net:3000
2. Login with credentials from vault
3. Verify pre-imported dashboards are visible
4. Access Uptime Kuma at http://monitoring.discus-moth.ts.net:3001
5. Complete initial setup and add service monitors
6. Configure alert notifications (optional)

**Notes**:

- Uses Podman instead of Docker for isolation
- All services run in `monitoring_net` bridge network
- Prometheus scrapes metrics every 15 seconds
- Grafana dashboards are pre-configured but customizable

---

### 15-configure-tdarr-role.yml

**Target**: jellyfin
**Roles**: podman_app

**Service**: Tdarr (Automated Transcoding)
**Ports**: 8265 (Web UI), 8266 (Server)
**URL**: http://jellyfin.discus-moth.ts.net:8265

**Purpose**: Automated media transcoding and optimization

---

### 16-configure-unbound-role.yml

**Target**: nas (192.168.0.15)
**Roles**: podman_app

**Service**: Unbound Recursive DNS Resolver (Podman)
**Port**: 5335 (localhost only)

**Features**:

- True recursive DNS (queries root servers directly)
- DNSSEC validation with auto trust anchor
- QNAME minimization for privacy
- Aggressive NSEC caching for performance
- Two-tier caching with AdGuard (8MB msg / 16MB rrset cache)
- Prefetch for popular domains
- Serve-expired for better availability

**Architecture**:

```text
Clients → AdGuard Home (filtering) → Unbound (recursive) → Root DNS servers
          Port 53                     Port 5335 (localhost)
```

**Benefits**:

- No dependency on third-party DNS providers
- Eliminates DoT connection pooling issues
- Enhanced privacy (no external DNS logging)
- Better performance with local caching
- Full control over DNS resolution

**Testing**:

```bash
# Test Unbound directly
dig @127.0.0.1 -p 5335 google.com

# Test DNSSEC validation (should fail)
dig @127.0.0.1 -p 5335 dnssec-failed.org

# Test full stack (AdGuard → Unbound)
dig @nas.discus-moth.ts.net google.com
```

**Dependencies**: Requires AdGuard Home (playbook 12) already deployed

---

### 17-configure-release-checker-stagger.yml

**Target**: All Ubuntu VMs
**Role**: common

**Purpose**: Stagger release checker timers to prevent CPU spikes

**Configures**:

- Staggers Ubuntu release upgrade checker across weekdays
- Prevents simultaneous CPU-intensive checks on all VMs
- Each VM assigned a specific day based on host_vars configuration

---

### 18-configure-woodpecker-ci-role.yml

**Target**: woodpecker_ci
**Role**: podman_app

**Service**: Woodpecker CI Server + Agent
**Port**: 8000 (Web UI), 9000 (gRPC)
**URL**: http://automation.discus-moth.ts.net:8000

**Purpose**: Continuous Integration/Continuous Deployment

**Features**:

- GitHub OAuth integration
- Podman-based build agents
- Pipeline-as-code with .woodpecker.yml files

---

### 19-configure-minio-role.yml

**Target**: nas
**Role**: podman_app

**Service**: MinIO Object Storage
**Ports**: 9000 (S3 API), 9001 (Console)
**URL**: http://nas.discus-moth.ts.net:9001

**Purpose**: S3-compatible object storage for Terraform state backend

---

### 20-configure-nexus-role.yml

**Target**: nas
**Role**: podman_app
**Phase**: 2 (required before Phase 3 services)

**Service**: Nexus Repository Manager
**Ports**: 8081 (Web UI), 5000 (Docker hosted), 5001 (Docker group)
**URL**: http://nas.discus-moth.ts.net:8081

**Purpose**: Container registry and artifact cache

**Features**:

- Host custom CI images
- Cache external container images locally
- Proxy registries: docker.io, ghcr.io, quay.io, lscr.io

**Note**: Deployed in Phase 2 because Phase 3 services (media-services, download-clients) pull container
images from this registry.

---

## Utility Playbooks

### cleanup-vms.yml

**Purpose**: Destroy all VMs (DANGER!)
**Use**: Clean slate for redeployment

### update-media.yml

**Purpose**: Update media service containers
**Use**: Pull latest images and restart services

---

## Variables and Configuration

### playbooks/vars.yml

Contains all VM definitions:

- VMID, cores, RAM, disk
- IP addresses
- CPU pinning configuration
- Resource priorities (cpu_units)

### group_vars/all.sops.yaml (SOPS-encrypted)

Contains sensitive data:

- Proxmox API password
- Tailscale API key
- NFS UID/GID (3000)
- Service API keys (Sonarr, Radarr)

**Edit**: `sops group_vars/all.sops.yaml`

### host_vars/*.yml

Per-VM configuration:

- Firewall ports
- Docker compose settings
- Service-specific variables

---

## Common Commands

```bash
# Test connectivity
ansible all -m ping -i inventory.ini

# Run specific playbook
./bin/runtime/ansible-run.sh playbooks/core/NN-playbook-name-role.yml

# Dry run (check mode)
./bin/runtime/ansible-run.sh playbooks/main.yml --check

# Syntax check
ansible-playbook playbooks/main.yml --syntax-check

# View secrets
sops -d group_vars/all.sops.yaml
```

---

## Execution Order Dependencies

**Phase 1** → **Phase 2** → **Phase 3** → Manual GUI Config → **Phase 4**

**Phase 5** (optional): Can run independently after Phase 2 (requires Tailscale networking)
**Phase C** (optional): Advanced services can run after Phase 4

Within phases:

- 01 must run first (creates VMs)
- 00, 02-03, 12, 20 can run in any order after 01 (Phase 2)
- 20 (Nexus) must run before Phase 3 (services pull from container registry)
- 04-07 require VMs to exist and Nexus deployed (Phase 3)
- 09 requires 02 (NAS must be configured)
- 10 requires 09 (NFS mount needed)
- 08, 11 should run last (Phase 4: Recyclarr + system hardening)
- 13-14 (Phase 5): 13 → 14 (sequential, exporters → monitoring stack)
- 15-19 (Phase C): Advanced services, can run independently

**Idempotency**: All playbooks are idempotent (safe to re-run)

---

## Troubleshooting Failed Playbooks

1. **Check connectivity**: `ansible all -m ping`
2. **View error**: Read playbook output carefully
3. **Check prerequisites**: Ensure previous playbooks succeeded
4. **Re-run**: Most playbooks are idempotent
5. **Check logs**: On target VM, check `journalctl` or service logs

See [Troubleshooting Guide](../troubleshooting/common-issues.md) for more help.

---

## See Also

- [Architecture Overview](../architecture.md)
- [Deployment Guide](../deployment/post-deployment.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [VM Specifications](vm-specifications.md)
