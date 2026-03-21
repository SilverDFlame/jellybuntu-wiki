# Virtual Machines

> 15 VMs on a single Proxmox host (AMD EPYC 7313P, 128 GB RAM).
> Source of truth: [`infrastructure/terraform/vms.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf)

## VM Inventory

| VM | VMID | IP | VLAN | vCPU | RAM | Disk | Purpose | Boot Order |
|----|------|----|------|------|-----|------|---------|------------|
| nas | 300 | 192.168.30.15 | media (30) | 2 | 6 GB | 32 GB | Btrfs NAS, NFS server, AdGuard Home, Unbound, Nexus | 1 |
| jellyfin | 400 | 192.168.30.12 | media (30) | 4 | 8 GB | 80 GB | Jellyfin media server (native systemd) | 2 |
| home-assistant | 100 | 192.168.20.10 | iot (20) | 2 | 2 GB | 40 GB | Home Assistant smart home hub | 5 |
| satisfactory-server | 200 | 192.168.40.11 | games (40) | 4 | 8 GB | 60 GB | Satisfactory dedicated server (cores 4–7 pinned) | 6 |
| monitoring | 500 | 192.168.10.16 | management (10) | 2 | 4 GB | 64 GB | Prometheus, Alertmanager, Grafana | 7 |
| woodpecker-ci | 600 | 192.168.10.17 | management (10) | 2 | 8 GB | 32 GB | Woodpecker CI server | 5 |
| lancache | 700 | 192.168.40.18 | games (40) | 2 | 4 GB | 32 GB | LAN cache for Steam, Epic, Battle.net downloads | 8 |
| k8s-control | 410 | 192.168.30.40 | media (30) | 2 | 4 GB | 40 GB | k3s control plane | 15 |
| k8s-gpu | 411 | 192.168.30.41 | media (30) | 4 | 16 GB | 60 GB | k3s GPU worker — Jellyfin + Tdarr (GTX 1080 passthrough) | 16 |
| k8s-media | 412 | 192.168.30.42 | media (30) | 4 | 8 GB | 60 GB | k3s media worker — arr stack | 16 |
| k8s-net | 413 | 192.168.30.43 | media (30) | 2 | 4 GB | 40 GB | k3s network worker — MetalLB speaker + Traefik ingress | 16 |
| k8s-ops | 414 | 192.168.30.44 | media (30) | 4 | 16 GB | 80 GB | k3s ops worker — Synapse, PostgreSQL, Prometheus, Grafana, Woodpecker | 16 |
| db | 415 | 192.168.30.16 | media (30) | 2 | 4 GB | 40 GB | Centralized PostgreSQL for k3s services | 2 |
| reverse-proxy | 900 | 192.168.10.20 | management (10) | 1 | 512 MB | 32 GB | Traefik v3 — Tailscale TLS termination for VM services | 5 |
| unifi-controller | 800 | 192.168.10.19 | management (10) | 2 | 2 GB | 32 GB | UniFi Network Application for AP management | 9 |

All VMs clone from the same Packer-built golden image. CPU type is `host` on all VMs. The Satisfactory server
uses CPU affinity (`cores 4–7`) to pin dedicated EPYC cores; cores 0–3 are reserved for a future Minecraft
server.

## VLANs

| VLAN | ID | CIDR | Gateway | Purpose |
|------|----|------|---------|---------|
| management | 10 | 192.168.10.0/24 | 192.168.10.1 | Infrastructure services (CI, proxy, monitoring, UniFi) |
| iot | 20 | 192.168.20.0/24 | 192.168.20.1 | IoT devices and Home Assistant |
| media | 30 | 192.168.30.0/24 | 192.168.30.1 | NAS, media stack, k3s cluster |
| games | 40 | 192.168.40.0/24 | 192.168.40.1 | Game servers and LAN cache |
| cameras | 50 | 192.168.50.0/24 | 192.168.50.1 | Security cameras (future use) |

Gateway is always `.1` (`cidrhost()` derived). All VMs use a single network bridge with 802.1q VLAN tagging.
NAS and Lancache enable jumbo frames (MTU 9000).

## Resource Totals

| Resource | Total (active VMs) |
|----------|--------------------|
| vCPU | 39 cores |
| RAM | 94.5 GB |
| Disk (OS volumes) | 754 GB |

Host: AMD EPYC 7313P (16c/32t), 128 GB ECC RAM. The GPU worker (k8s-gpu) also holds a GTX 1080
via PCIe passthrough — see [GPU](gpu.md).
