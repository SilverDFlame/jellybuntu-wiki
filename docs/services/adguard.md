# AdGuard Home + Unbound

> Network-wide DNS filtering and recursive resolution for all VLANs

| Field | Value |
|-------|-------|
| **Runs on** | NAS VM (VMID 300), `192.168.30.15` |
| **Access** | `http://192.168.30.15:80` (web UI, LAN only) |
| **Ports** | 53 (DNS), 80 (web UI), 5335 (Unbound, localhost only) |
| **Repo** | [`playbooks/networking/adguard-home.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/networking/adguard-home.yml) and [`services/configs/adguard-vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/adguard-vars.yml) |

## Architecture

AdGuard Home and Unbound run as Podman containers on the NAS VM.

```text
Client query
  -> AdGuard Home :53 (filtering + DNSSEC)
       -> Unbound :5335 (recursive resolver, localhost only)
            -> Root hints (iterative resolution)
       -> [/ts.net/] 100.100.100.100 (Tailscale MagicDNS)
       -> tls://dns.quad9.net (fallback if Unbound unavailable)
```

## Key Config

- AdGuard version pinned: `v0.107.68` (critical DNS infrastructure — manual upgrades)
- DNSSEC validation enabled; query logs retained for 90 days
- Rate limit: 20 queries/second per client IP
- DNS available to all VLANs: Management (10), IoT (20), Media (30), Games (40), Cameras (50)
- NAS Tailscale mode is **non-ephemeral** so DNS stays reachable after network outages

**Blocklists active:**

- AdGuard DNS filter
- AdAway Default Blocklist
- OISD Big + OISD NSFW
- Hagezi Pro++ and Hagezi Porn Ultimate
- Steven Black Unified (fakenews + gambling + porn)
- Block List Project (Porn, Malware)
- DandelionSprout Anti-Malware

**DNS rewrites** — all k3s services resolve to the MetalLB VIP `192.168.30.200` (k3s Traefik).
See [infrastructure/networking.md](../infrastructure/networking.md) for the full rewrite table.

## Common Operations

```bash
# Deploy / reconfigure
./bin/runtime/ansible-run.sh playbooks/networking/adguard-home.yml

# Check container status on NAS
ssh nas.discus-moth.ts.net podman ps --filter name=adguard

# Restart AdGuard
ssh nas.discus-moth.ts.net sudo systemctl restart podman-adguard

# Restart Unbound
ssh nas.discus-moth.ts.net sudo systemctl restart podman-unbound

# Test DNS resolution
dig @192.168.30.15 sonarr.elysium.industries
dig @192.168.30.15 nas.discus-moth.ts.net
```
