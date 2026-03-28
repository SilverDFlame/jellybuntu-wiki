# Jellybuntu

> Hybrid Proxmox VM + k3s homelab on an AMD EPYC 7313P

## Services

| Service | URL | Runs On |
|---------|-----|---------|
| Jellyfin | [jellyfin.elysium.industries](https://jellyfin.elysium.industries) | k3s `gpu` namespace |
| Tdarr | [tdarr.elysium.industries](https://tdarr.elysium.industries) | k3s `gpu` namespace |
| Sonarr | [sonarr.elysium.industries](https://sonarr.elysium.industries) | k3s `media` namespace |
| Radarr | [radarr.elysium.industries](https://radarr.elysium.industries) | k3s `media` namespace |
| Lidarr | [lidarr.elysium.industries](https://lidarr.elysium.industries) | k3s `media` namespace |
| Prowlarr | [prowlarr.elysium.industries](https://prowlarr.elysium.industries) | k3s `media` namespace |
| Bazarr | [bazarr.elysium.industries](https://bazarr.elysium.industries) | k3s `media` namespace |
| Jellyseerr | [jellyseerr.elysium.industries](https://jellyseerr.elysium.industries) | k3s `media` namespace |
| Navidrome | [navidrome.elysium.industries](https://navidrome.elysium.industries) | k3s `media` namespace |
| qBittorrent | [qbittorrent.elysium.industries](https://qbittorrent.elysium.industries) | k3s `media` namespace |
| SABnzbd | [sabnzbd.elysium.industries](https://sabnzbd.elysium.industries) | k3s `media` namespace |
| Byparr | [byparr.elysium.industries](https://byparr.elysium.industries) | k3s `media` namespace |
| Matrix (Element) | [chat.elysium.industries](https://chat.elysium.industries) | k3s `ops` namespace |
| Synapse Admin | [synapse-admin.elysium.industries](https://synapse-admin.elysium.industries) | k3s `ops` namespace |
| LiveKit | [livekit.elysium.industries](https://livekit.elysium.industries) | k3s `ops` namespace |
| LiveKit JWT | [lk-jwt.elysium.industries](https://lk-jwt.elysium.industries) | k3s `ops` namespace |
| Home Assistant | Tailscale only | home-assistant VM (VMID 100, 192.168.20.10) |
| Satisfactory | Direct UDP | satisfactory-server VM (VMID 200, 192.168.40.11) |
| NAS | Tailscale only | nas VM (VMID 300, 192.168.30.15) |
| Monitoring (Grafana) | Tailscale only | monitoring VM (VMID 500, 192.168.10.16) |
| Woodpecker CI | Tailscale only | woodpecker-ci VM (VMID 600, 192.168.10.17) |
| Lancache | LAN only | lancache VM (VMID 700, 192.168.40.18) |
| UniFi Controller | Tailscale only | unifi-controller VM (VMID 800, 192.168.10.19) |
| Reverse Proxy | Internal | reverse-proxy VM (VMID 900, 192.168.10.20) |

## Repositories

| Repo | Description |
|------|-------------|
| [jellybuntu](https://github.com/SilverDFlame/jellybuntu) | Ansible/Terraform IaC |
| [jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) | Flux GitOps k3s manifests |
| [jellybuntu-wiki](https://github.com/SilverDFlame/jellybuntu-wiki) | This documentation |

## Start Here

- [Architecture](architecture.md) — system design and topology
- [Deployment](operations/deployment.md) — phase-based deployment
- [k3s Cluster](operations/k3s-cluster.md) — Flux GitOps workflow
