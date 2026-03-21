# Networking

> VLANs, DNS, ingress, and Tailscale overlay.

## VLAN Architecture

Five VLANs provide traffic segmentation across the single Proxmox host. All VMs connect via a single
802.1q-tagged bridge. See the full VLAN table in [Virtual Machines](vms.md#vlans).

Key segmentation decisions:

- The k3s cluster and NAS share the **media VLAN (30)** to keep NFS traffic local without cross-VLAN routing.
- Game servers and LAN cache are isolated in **games VLAN (40)**.
- Management infrastructure (CI, proxy, monitoring) lives in **management VLAN (10)**, with firewall rules
  permitting DNS queries inbound from all other VLANs.

## DNS Chain

```text
Client query
  -> AdGuard Home (NAS, port 53)
       -> Tailscale MagicDNS (100.100.100.100) for *.ts.net domains
       -> Unbound recursive resolver (localhost:5335) for everything else
            -> Authoritative nameservers (internet)
       -> DoT fallback: Quad9 (dns11.quad9.net), Cloudflare (1dot1dot1dot1.cloudflare-dns.com)
```

AdGuard Home runs on the NAS VM (192.168.30.15, port 53). Unbound listens on localhost:5335 and performs
full recursive resolution. DNSSEC validation is enabled on both. Query logs are retained for 90 days.

### Blocklists

| List | URL |
|------|-----|
| AdGuard DNS filter | `https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt` |
| AdAway Default | `https://adaway.org/hosts.txt` |
| OISD Big | `https://big.oisd.nl/` |
| Hagezi Pro++ | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt` |
| Steven Black (FGP) | `https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts` |
| OISD NSFW | `https://nsfw.oisd.nl/` |
| Hagezi Porn Ultimate | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt` |
| Block List Project — Porn | `https://blocklistproject.github.io/Lists/porn.txt` |
| DandelionSprout Anti-Malware | `https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuardHome.txt` |
| Block List Project — Malware | `https://blocklistproject.github.io/Lists/malware.txt` |

Rate limiting: 20 queries/second per client IP. Lists update every 24 hours.

## DNS Rewrites

All `*.elysium.industries` rewrites point to the k3s Traefik MetalLB VIP **192.168.30.200**.
The VM Traefik rewrite list is currently empty — all services have migrated to k3s.

| Domain | Target | Worker |
|--------|--------|--------|
| chat.elysium.industries | 192.168.30.200 | k8s-ops |
| synapse-admin.elysium.industries | 192.168.30.200 | k8s-ops |
| lk-jwt.elysium.industries | 192.168.30.200 | k8s-ops |
| livekit.elysium.industries | 192.168.30.200 | k8s-ops |
| sonarr.elysium.industries | 192.168.30.200 | k8s-media |
| radarr.elysium.industries | 192.168.30.200 | k8s-media |
| prowlarr.elysium.industries | 192.168.30.200 | k8s-media |
| jellyseerr.elysium.industries | 192.168.30.200 | k8s-media |
| bazarr.elysium.industries | 192.168.30.200 | k8s-media |
| lidarr.elysium.industries | 192.168.30.200 | k8s-media |
| navidrome.elysium.industries | 192.168.30.200 | k8s-media |
| byparr.elysium.industries | 192.168.30.200 | k8s-media |
| qbittorrent.elysium.industries | 192.168.30.200 | k8s-media |
| sabnzbd.elysium.industries | 192.168.30.200 | k8s-media |
| jellyfin.elysium.industries | 192.168.30.200 | k8s-gpu |
| tdarr.elysium.industries | 192.168.30.200 | k8s-gpu |

Source:
[`services/configs/adguard-vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/adguard-vars.yml)

## Ingress

### k3s Traefik (primary)

MetalLB allocates IPs from the pool `192.168.30.200/29` via L2 advertisement. Traefik runs on the
**k8s-net** worker node (413, 192.168.30.43) and handles all `*.elysium.industries` traffic.

```text
Client -> 192.168.30.200:443 (MetalLB VIP)
       -> Traefik (k8s-net)
       -> Service ClusterIP -> Pod
```

MetalLB config:
[`clusters/jellybuntu/net/metallb-config.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf)

### VM Traefik (legacy)

The **reverse-proxy** VM (900, 192.168.10.20) runs Traefik v3 for any remaining VM-hosted services.
Currently no active rewrites — all services have migrated to k3s. The VM remains available as a fallback.

## TLS

Traefik obtains a single wildcard certificate `*.elysium.industries` from Let's Encrypt using the
Cloudflare DNS-01 challenge. The certificate covers all `*.elysium.industries` subdomains.

- ACME CA: `https://acme-v02.api.letsencrypt.org/directory`
- Challenge: Cloudflare DNS-01 (API token scoped to `Zone:DNS:Edit` on `elysium.industries`)
- DNS resolvers for challenge verification: `1.1.1.1:53`, `8.8.8.8:53` (bypasses local AdGuard to avoid
  checking split-horizon rewrites)
- Storage: `acme.json` on the Traefik container host
- Auto-renewal: ~30 days before expiry

TLS policy enforces TLS 1.2 minimum with `sniStrict: true`. Cipher suites use ECDHE with AES-256-GCM,
AES-128-GCM, and ChaCha20-Poly1305.

Source:
[`roles/traefik_proxy/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/traefik_proxy)

## Tailscale

Tailscale provides the remote-access overlay network. All VMs join the `discus-moth.ts.net` tailnet.

- Hostnames: `<vm>.discus-moth.ts.net` — used for direct VM access outside the LAN
- MagicDNS: enabled; `*.ts.net` queries are forwarded to `100.100.100.100` by AdGuard
- NAS is configured as non-ephemeral (`tailscale_ephemeral: false`) so that AdGuard DNS remains
  reachable after a reboot or network outage — ephemeral nodes are auto-removed when offline
- The VM Traefik (reverse-proxy) uses Tailscale TLS certificates (`*.discus-moth.ts.net`) for its
  own dashboard and any remaining VM services
