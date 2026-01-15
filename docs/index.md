# Jellybuntu Documentation

Complete documentation for the Jellybuntu Proxmox homelab infrastructure.

## Quick Links

- **[Quickstart Guide](quickstart.md)** - Get up and running fast
- **[Architecture Overview](architecture.md)** - Infrastructure design and patterns
- **[Service Endpoints](configuration/service-endpoints.md)** - Access your services

## Documentation Structure

### 📦 Deployment

Step-by-step deployment guides for the infrastructure:

- **[Initial Setup](deployment/initial-setup.md)** - Bootstrap script, Ansible vault, SSH keys
- **[Phase-Based Deployment](deployment/phase-based-deployment.md)** - Complete deployment workflow guide
- **[Phase 1: Infrastructure](deployment/phase1-infrastructure.md)** - VM provisioning on Proxmox
- **[Phase 2: Networking](deployment/phase2-networking.md)** - NAS + Tailscale configuration
- **[Phase 3: Services](deployment/phase3-services.md)** - Media services and download clients
- **[Phase 4: Post-Deployment](deployment/phase4-post-deployment.md)** - Firewall and auto-updates
- **[Phase 5: Monitoring](deployment/phase5-monitoring.md)** - Prometheus/Grafana/Uptime Kuma (optional)
- **[Golden Image Workflow](deployment/golden-image-workflow.md)** - Packer golden image builds and VM templates
- **[Woodpecker CI](deployment/woodpecker-ci.md)** - CI/CD pipeline setup and configuration

### ⚙️ Configuration

Configuration guides for services and infrastructure:

- **[Service Endpoints](configuration/service-endpoints.md)** - All service URLs and ports
- **[Service Integration Checklist](configuration/service-integration-checklist.md)** - Step-by-step service integration

  and testing

- **[User Onboarding Guide](configuration/user-onboarding.md)** - Creating and managing user accounts
- **[Networking](configuration/networking.md)** - Firewall, Tailscale, network segmentation
- **[Security](configuration/security.md)** - Authentication, vault, Proxmox API
- **[Resource Allocation](configuration/resource-allocation.md)** - CPU/RAM allocation, priorities
- **[Container Resource Management](configuration/container-resource-management.md)** - Container resource limits

#### Service-Specific Configuration

- **[Jellyseerr Setup](configuration/jellyseerr-setup.md)** - Request management configuration
- **[Unpackerr Setup](configuration/unpackerr-setup.md)** - Automatic archive extraction
- **[VPN/Gluetun Configuration](configuration/vpn-gluetun.md)** - VPN setup and port forwarding
- **[AdGuard Home Setup](configuration/adguard-home.md)** - DNS filtering and ad blocking
- **[Bazarr Setup](configuration/bazarr-setup.md)** - Subtitle automation
- **[Huntarr Setup](configuration/huntarr-setup.md)** - Finding missing media content
- **[Tdarr Setup](configuration/tdarr-setup.md)** - Automated media transcoding setup
- **[Tdarr Flow Configuration](configuration/tdarr-flow-configuration.md)** - Tdarr flow and pipeline design
- **[Tdarr Transcode Profiles](configuration/tdarr-transcode-profiles.md)** - Codec profiles and optimization settings
- **[Nexus Registry](configuration/nexus-registry.md)** - Container registry setup and configuration
- **[Monitoring Stack Setup](configuration/monitoring-stack-setup.md)** - Prometheus, Grafana, and alerting configuration
- **[Uptime Kuma Setup](configuration/uptime-kuma-setup.md)** - Service monitoring and notification setup
- **[Service Optimization Checklist](configuration/service-optimization-checklist.md)** - Performance tuning guide

### 💻 Development

Development tools and workflows:

- **[Pre-commit Hooks](development/pre-commit.md)** - Automated code quality checks and linting

### 🔧 Maintenance

Ongoing maintenance and management:

- **[Updates](maintenance/updates.md)** - Service updates, unattended upgrades
- **[Power Management](maintenance/power-management.md)** - VM startup/shutdown automation
- **[Backup and Recovery](maintenance/backup-recovery.md)** - Backup strategies and disaster recovery procedures
- **[Nexus Maintenance](maintenance/nexus-maintenance.md)** - Registry cleanup policies, disk management, scheduled tasks
- **[Btrfs Maintenance](maintenance/btrfs-maintenance.md)** - Snapshots, scrubs, balance operations, health checks
- **[Monitoring Maintenance](maintenance/monitoring-maintenance.md)** - Prometheus retention, Grafana backups, alert management
- **[Woodpecker Maintenance](maintenance/woodpecker-maintenance.md)** - Log cleanup, build artifacts, secrets rotation
- **[AdGuard Maintenance](maintenance/adguard-maintenance.md)** - Query logs, filter updates, DNS health checks
- **[Troubleshooting](maintenance/troubleshooting.md)** - Common issues and solutions

### 🔍 Troubleshooting

Service-specific troubleshooting guides:

- **[Common Issues](troubleshooting/common-issues.md)** - Cross-service problems and general troubleshooting
- **[Jellyfin](troubleshooting/jellyfin.md)** - Transcoding, performance, library issues
- **[Jellyseerr](troubleshooting/jellyseerr.md)** - Request management issues
- **[Satisfactory](troubleshooting/satisfactory.md)** - Game server crashes, connectivity, SMM issues
- **[Sonarr/Radarr](troubleshooting/sonarr-radarr.md)** - Media management, API, indexer issues
- **[Prowlarr](troubleshooting/prowlarr.md)** - Indexer connectivity and sync issues
- **[Download Clients](troubleshooting/download-clients.md)** - qBittorrent and SABnzbd issues
- **[FlareSolverr](troubleshooting/flaresolverr.md)** - Cloudflare bypass issues
- **[Recyclarr](troubleshooting/recyclarr.md)** - Quality profile sync troubleshooting
- **[VPN/Gluetun](troubleshooting/vpn-gluetun.md)** - VPN connectivity and port forwarding
- **[Tdarr](troubleshooting/tdarr.md)** - Transcoding issues, worker problems, library management
- **[NAS/NFS](troubleshooting/nas-nfs.md)** - Btrfs, NFS mounts, snapshots, maintenance
- **[Networking](troubleshooting/networking.md)** - Tailscale, firewall, SSH access
- **[Network Performance](troubleshooting/network-performance.md)** - Bandwidth, latency, and throughput issues
- **[DNS](troubleshooting/dns.md)** - DNS resolution and AdGuard Home
- **[Podman/Containers](troubleshooting/podman.md)** - Container and Quadlet issues
- **[Monitoring](troubleshooting/monitoring.md)** - Prometheus, Grafana, and Uptime Kuma issues
- **[Packer](troubleshooting/packer.md)** - Golden image build failures and debugging
- **[UFW Firewall](troubleshooting/ufw-firewall.md)** - Firewall rule issues and connectivity problems
- **[Woodpecker CI](troubleshooting/woodpecker-ci.md)** - CI/CD pipeline failures and agent issues
- **[Home Assistant](troubleshooting/home-assistant.md)** - Home automation, integrations, database issues
- **[AdGuard Home](troubleshooting/adguard-home.md)** - DNS filtering, query logs, upstream resolution
- **[Bazarr](troubleshooting/bazarr.md)** - Subtitle downloads, provider issues, library sync
- **[Huntarr](troubleshooting/huntarr.md)** - Missing content discovery, scheduling, connections
- **[Unpackerr](troubleshooting/unpackerr.md)** - Archive extraction, path configuration, permissions
- **[Uptime Kuma](troubleshooting/uptime-kuma.md)** - Monitor configuration, notifications, status pages
- **[Nexus Repository](troubleshooting/nexus.md)** - Container registry, authentication, disk management

### 📚 Reference

Detailed reference documentation:

- **[Playbooks Reference](reference/playbooks.md)** - All playbook descriptions
- **[Proxmox API Permissions](reference/proxmox-api-permissions.md)** - API user permission breakdown
- **[Tailscale Auto-Approval](reference/tailscale-auto-approval.md)** - ACL configuration
- **[SSH Bastion](reference/ssh-bastion.md)** - SSH bastion host configuration and usage
- **[NAS Setup](reference/nas-setup.md)** - Btrfs RAID1 NAS installation and NFS configuration
- **[Btrfs Optimization](reference/btrfs-optimization.md)** - Filesystem tuning, snapshots, and maintenance
- **[VM Specifications](reference/vm-specifications.md)** - Detailed VM resource allocation and configuration
- **[Media Services Workflow](reference/media-services-workflow.md)** - Complete media automation pipeline
- **[Media Quality Profiles](reference/media-quality-profiles.md)** - Recyclarr quality profile configuration
- **[Modular Architecture](reference/modular-architecture.md)** - Podman Quadlet and Ansible role structure
- **[Memory Tuning](reference/memory-tuning.md)** - Container memory limits, best practices, monitoring

## Infrastructure Overview

### VMs

- **Home Assistant** (VMID 100, 192.168.0.10) - Home automation
- **Satisfactory** (VMID 200, 192.168.0.11) - Game server with CPU pinning
- **NAS** (VMID 300, 192.168.0.15) - Btrfs RAID1 NFS storage (6GB RAM)
- **Jellyfin** (VMID 400, 192.168.0.12) - Media server (4 cores, 8GB RAM, optimized for 4K)
- **Media Services** (VMID 401, 192.168.0.13) - Sonarr, Radarr, Prowlarr, Jellyseerr
- **Download Clients** (VMID 402, 192.168.0.14) - qBittorrent, SABnzbd
- **Monitoring** (VMID 500, 192.168.0.16) - Prometheus, Grafana, Uptime Kuma (optional)

### Key Features

- **Phase-Based Deployment** - Infrastructure → Networking → Services (or deploy all at once)
- **Podman Quadlet Architecture** - Rootless containers with native systemd integration
- **Isolated Download Clients** - Dedicated VM for better resource management
- **Btrfs RAID1 NAS** - Reliable storage with snapshots and NFS exports
- **Tailscale Integration** - Secure remote access to all services
- **Automated Deployment** - Full infrastructure-as-code with Ansible
- **UFW Firewall** - Network segmentation and access control
- **Unattended Upgrades** - Automatic security updates

## Getting Started

1. Read the [Architecture Overview](architecture.md) to understand the infrastructure
2. Follow the [Quickstart Guide](quickstart.md) for rapid deployment
3. Consult [Deployment guides](deployment/initial-setup.md) for detailed setup steps
4. Configure services using [Configuration guides](configuration/service-endpoints.md)
5. Set up maintenance with [Maintenance guides](maintenance/updates.md)

## Project Structure

```text
├── CLAUDE.md                         # Quick reference for Claude Code
├── README.md                         # Project overview
├── docs/                             # This documentation
├── playbooks/                        # Ansible playbooks
│   ├── main.yml                      # Complete deployment (all phases)
│   ├── phases/                       # Phase-based orchestration
│   │   ├── phase1-infrastructure.yml
│   │   ├── phase2-networking.yml
│   │   ├── phase3-services.yml
│   │   ├── phase4-post-deployment.yml
│   │   └── phase5-monitoring.yml
│   ├── core/                         # Individual role playbooks (01-14, 15-17)
│   │   ├── 01-provision-vms.yml
│   │   ├── 02-configure-nas-role.yml
│   │   ├── 03-configure-tailscale-role.yml
│   │   └── ...
│   └── utility/                      # One-off utilities
├── roles/                            # Ansible roles (reusable)
│   ├── podman_app/                   # Quadlet container deployment
│   ├── tailscale/
│   ├── jellyfin/
│   └── ...
├── services/                         # Service configurations (legacy)
│   └── configs/                      # Configuration templates
│       ├── sabnzbd.ini.j2
│       └── recyclarr-config.yaml
├── inventory.ini                     # Ansible inventory
└── setup.sh                          # Bootstrap script
```

## Support and Contribution

This is a personal homelab project. Documentation is maintained for reference and to assist Claude Code in understanding
the infrastructure.

**Key Technologies:**

- Proxmox VE - Virtualization
- Ansible - Infrastructure automation
- Podman Quadlet - Rootless container orchestration with systemd
- Tailscale - VPN/mesh networking
- Btrfs RAID1 NAS - Network storage with snapshots
