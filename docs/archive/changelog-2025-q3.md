# Changelog Archive: 2025 Q3 (July - September)

This document archives infrastructure changes from Q3 2025 that have aged out of the active
[RECENT_CHANGES.md](https://github.com/SilverDFlame/jellybuntu/blob/main/RECENT_CHANGES.md) file.

---

## September 2025

### Phase 3 Service Deployment Complete

**Timeline:** Throughout September 2025

The core media services infrastructure was deployed during this period, establishing the foundation for
the homelab's media management capabilities.

#### Media Services Stack

Deployed the following services on the media-services VM (VMID 200):

- **Sonarr** - TV show management and automation
- **Radarr** - Movie management and automation
- **Prowlarr** - Indexer management for Sonarr/Radarr
- **Jellyseerr** - Media request management
- **Bazarr** - Subtitle management
- **Recyclarr** - TRaSH Guides sync for quality profiles

#### Download Clients

Deployed on download-clients VM (VMID 201) with VPN protection:

- **Gluetun** - VPN container (Private Internet Access)
- **qBittorrent** - Torrent client (routed through Gluetun)
- **SABnzbd** - Usenet client (routed through Gluetun)
- **Unpackerr** - Automatic extraction for completed downloads

#### Jellyfin Installation

Completed native Jellyfin installation on dedicated VM (VMID 400):

- Native package installation (not containerized) for better hardware acceleration support
- Configured for future GPU passthrough capability
- NFS mounts to shared media storage on NAS

#### Infrastructure Notes

- All services deployed using Docker Compose (later migrated to Podman Quadlet in November 2025)
- NFS storage configured for media library access
- Inter-service communication via Docker networks
- Basic monitoring via Uptime Kuma health checks

---

## August 2025

### Phase 2 Networking and Core Services

- **Tailscale** deployment across all VMs for secure mesh networking
- **AdGuard Home** DNS server deployment
- Initial firewall rules established

### Phase 1 Infrastructure Provisioning

- **OpenTofu** infrastructure-as-code established
- Core VM provisioning automated
- Proxmox API integration configured

---

## July 2025

### Project Inception

- Initial repository structure created
- Ansible playbook framework established
- Documentation structure defined

---

## Related Archives

Other archived documentation from this period:

- [Memory Alerts Analysis (Oct 2025)](memory-alerts-analysis-20251031.md) - Memory limit investigation
- [Docker Troubleshooting](docker-troubleshooting.md) - Legacy Docker documentation (pre-Podman migration)
- [TrueNAS Setup](truenas-setup.md) - Original NAS configuration (migrated to Ubuntu+Btrfs in October)
- [Portainer Setup](portainer-setup.md) - Legacy container management (removed in November)
- [Homepage Setup](homepage-setup.md) - Legacy dashboard (replaced by Homarr)

---

*Archived: January 16, 2026*
*Source: RECENT_CHANGES.md monthly audit*
