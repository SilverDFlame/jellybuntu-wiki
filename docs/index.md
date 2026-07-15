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
| Jellyseerr | [seerr.elysium.industries](https://seerr.elysium.industries) | k3s `media` namespace |
| Navidrome | [navidrome.elysium.industries](https://navidrome.elysium.industries) | k3s `media` namespace |
| Deluge | [deluge.elysium.industries](https://deluge.elysium.industries) | k3s `media` namespace |
| autobrr | [autobrr.elysium.industries](https://autobrr.elysium.industries) | k3s `media` namespace |
| Byparr | [byparr.elysium.industries](https://byparr.elysium.industries) | k3s `media` namespace |
| Ollama | [ollama.elysium.industries](https://ollama.elysium.industries) | k3s `gpu` namespace |
| Seedbox Orchestrator | Tailscale only | nas VM (usenet/torrent transport) |
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
- [k3s Namespaces](operations/k3s-namespaces.md) — service ports, URLs, access policy
- [Helm Repo Layout](operations/helm-repo.md) — jellybuntu-helm structure and SOPS
