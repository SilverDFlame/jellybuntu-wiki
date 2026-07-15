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

All `*.elysium.industries` rewrites point to the k3s Traefik VIP **192.168.30.200**
(Cilium LB-IPAM, advertised via L2 announcer).
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
| seerr.elysium.industries | 192.168.30.200 | k8s-media |
| bazarr.elysium.industries | 192.168.30.200 | k8s-media |
| lidarr.elysium.industries | 192.168.30.200 | k8s-media |
| navidrome.elysium.industries | 192.168.30.200 | k8s-media |
| byparr.elysium.industries | 192.168.30.200 | k8s-media |
| deluge.elysium.industries | 192.168.30.200 | k8s-media |
| autobrr.elysium.industries | 192.168.30.200 | k8s-media |
| jellyfin.elysium.industries | 192.168.30.200 | k8s-gpu |
| tdarr.elysium.industries | 192.168.30.200 | k8s-gpu |
| ollama.elysium.industries | 192.168.30.200 | k8s-gpu |

Source:
[`services/configs/adguard-vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/adguard-vars.yml)

## Ingress

### k3s Traefik (primary)

Cilium LB-IPAM allocates IPs from the `jellybuntu-pool` (`192.168.30.200/29`).
A `CiliumL2AnnouncementPolicy` advertises the VIPs via ARP, pinned to nodes labelled
`jellybuntu.io/role=net` (currently k8s-net only) so leases never bounce to a node
without the upstream route. Traefik runs on **k8s-net** (413, 192.168.30.43) and
handles all `*.elysium.industries` traffic.

```text
Client -> 192.168.30.200:443 (Cilium LB-IPAM VIP, L2 announced by k8s-net)
       -> Traefik (k8s-net)
       -> Service ClusterIP -> Pod
```

Cilium IP pool + L2 announcement policy:
[`clusters/jellybuntu/net/`](https://github.com/SilverDFlame/jellybuntu-helm/tree/main/clusters/jellybuntu/net)

### VM Traefik (legacy)

The **reverse-proxy** VM (900, 192.168.10.20) runs Traefik v3 for any remaining VM-hosted services.
Currently no active rewrites — all services have migrated to k3s. The VM remains available as a fallback.

## CNI — Cilium

The k3s cluster runs **Cilium 1.19.4** as the sole CNI (migrated from flannel on 2026-05-29).
Kube-proxy is fully replaced by Cilium kpr — there is no `kube-proxy` DaemonSet. Pod-to-pod
traffic is encapsulated in a **VXLAN overlay on UDP/8472**.

LoadBalancer services are handled in-cluster by Cilium LB-IPAM, which allocates VIPs from
`jellybuntu-pool` (`192.168.30.200/29`) and announces them via ARP from nodes labelled
`jellybuntu.io/role=net` — see
[k3s-cluster.md § Cilium](../operations/k3s-cluster.md#cilium-cni-loadbalancer) for the pool,
L2 announcement policy, and inspection commands.

### Hubble

Hubble is enabled in the Cilium HelmRelease — observability for L3/L4/L7 flows and a
network map UI. The default event buffer size is **4095 flows**, which the cluster's
sustained traffic (~11.4 flows/s observed) saturates at 100%, giving about **6 minutes
of in-memory history**. Operators who need deeper retention can bump
`hubble.eventBufferCapacity` in the HelmRelease values.

Quick observe from any node:

```bash
kubectl exec -n kube-system ds/cilium -- hubble observe --last 100
```

The Hubble UI (when port-forwarded) is at `hubble-ui.kube-system.svc.cluster.local`.

### Firewall ports

Cilium control + data plane traffic must be permitted between k3s nodes (media VLAN 30):

| Proto | Port | Purpose |
|-------|------|---------|
| UDP | 8472 | VXLAN overlay (pod-to-pod) |
| TCP | 4240 | Cilium agent health check |
| TCP | 4244 | Hubble server (per-agent gRPC) |
| TCP | 4245 | Hubble Relay (cluster-wide aggregation) |

Legacy MetalLB ports (TCP/7946, UDP/7946, TCP/7472) are no longer required and have
been removed from the cluster — MetalLB itself was uninstalled as part of the migration.

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
