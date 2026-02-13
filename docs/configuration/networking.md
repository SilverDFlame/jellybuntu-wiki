# Networking Configuration

Complete guide to network architecture, firewall rules, and Tailscale VPN configuration.

> **Security Note**: The IP addresses documented here are private (RFC 1918) addresses on an isolated
> home network, accessible only via Tailscale VPN. They are not routable from the public internet.

!!! info "VLAN Migration (Feb 2026)"
    The infrastructure has migrated from flat 192.168.0.0/24 to VLAN-segmented networking.
    See [VLAN Migration Reference](../reference/vlan-migration.md) for the complete migration guide
    and legacy-to-VLAN IP mapping.

## Overview

The Jellybuntu infrastructure uses a dual-network approach:

- **Local VLANs**: Segmented LAN access (Management, IoT, Media, Games)
- **Tailscale VPN** (100.64.0.0/10): Secure remote access

This provides both local performance and secure remote connectivity.

## Network Architecture

### Local Network (VLAN-Segmented)

**Purpose**: Primary network for all services, segmented by function

**VLAN Subnets**:

| VLAN ID | Name | Subnet | Gateway | Purpose |
|---------|------|--------|---------|---------|
| 10 | Management | 192.168.10.0/24 | 192.168.10.1 | Infrastructure services |
| 20 | IoT | 192.168.20.0/24 | 192.168.20.1 | Home automation devices |
| 30 | Media | 192.168.30.0/24 | 192.168.30.1 | Media streaming and storage |
| 40 | Games | 192.168.40.0/24 | 192.168.40.1 | Game servers and caches |
| 50 | Cameras | 192.168.50.0/24 | 192.168.50.1 | Reserved for future use |

**DNS**: 9.9.9.9 (Quad9) primary, per-VLAN gateway as secondary

**IP Allocations**:

| VM ID | Device | IP | VLAN | Hostname | Purpose |
|-------|--------|-----|------|----------|---------|
| - | Proxmox Host | Varies | - | jellybuntu.discus-moth.ts.net | Hypervisor |
| 100 | Home Assistant | 192.168.20.10 | 20 (IoT) | home-assistant | Automation |
| 200 | Satisfactory | 192.168.40.11 | 40 (Games) | satisfactory-server | Game server |
| 201 | Mumble | 192.168.40.20 | 40 (Games) | mumble | Voice chat server |
| 300 | NAS | 192.168.30.15 | 30 (Media) | nas | Storage server |
| 400 | Jellyfin | 192.168.30.12 | 30 (Media) | jellyfin | Media streaming |
| 401 | Media Services | 192.168.30.13 | 30 (Media) | media-services | Sonarr/Radarr/etc |
| 402 | Download Clients | 192.168.30.14 | 30 (Media) | download-clients | qBittorrent/SABnzbd |
| 500 | Monitoring | 192.168.10.16 | 10 (Mgmt) | monitoring | Prometheus/Grafana |
| 600 | Woodpecker CI | 192.168.10.17 | 10 (Mgmt) | woodpecker | CI/CD pipeline |
| 700 | Lancache | 192.168.40.18 | 40 (Games) | lancache | Game download cache |
| 800 | UniFi Controller | 192.168.10.19 | 10 (Mgmt) | unifi-controller | Network management |

### Tailscale VPN (100.64.0.0/10)

**Purpose**: Secure remote access and encrypted VM-to-VM communication

**Features**:

- **End-to-end encryption**: All traffic encrypted via WireGuard
- **NAT traversal**: Works behind firewalls without port forwarding
- **Automatic DNS**: Hostnames like `nas.discus-moth.ts.net`
- **ACL support**: Fine-grained access control

**Hostnames**:
All VMs accessible via Tailscale hostnames:

- `home-assistant.discus-moth.ts.net`
- `satisfactory-server.discus-moth.ts.net`
- `mumble.discus-moth.ts.net`
- `jellyfin.discus-moth.ts.net`
- `media-services.discus-moth.ts.net`
- `download-clients.discus-moth.ts.net`
- `nas.discus-moth.ts.net`
- `monitoring.discus-moth.ts.net`
- `woodpecker.discus-moth.ts.net`
- `lancache.discus-moth.ts.net`
- `unifi-controller.discus-moth.ts.net`

### Network Flow Diagram

```text
┌──────────────────────────────────────────────────────────────────┐
│                    Proxmox Host (jellybuntu)                     │
│                                                                  │
│  VLAN 10 - Management (192.168.10.0/24)                          │
│  ┌────────────┐  ┌────────────┐  ┌──────────────────┐            │
│  │ .16 Monitor│  │ .17 Woodpkr│  │ .19 UniFi Ctrl   │            │
│  └─────┬──────┘  └─────┬──────┘  └───────┬──────────┘            │
│        └───────────────┼──────────────────┘                      │
│                        │                                         │
│  VLAN 20 - IoT (192.168.20.0/24)                                 │
│  ┌──────────────────┐                                            │
│  │ .10 Home Asst    │                                            │
│  └────────┬─────────┘                                            │
│           │                                                      │
│  VLAN 30 - Media (192.168.30.0/24)                               │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────────┐             │
│  │.12 JF  │  │.13 Med │  │.14 DL  │  │ .15 NAS    │             │
│  │Jellyfin│  │Services│  │Clients │  │ (NFS/DNS)  │             │
│  └───┬────┘  └───┬────┘  └───┬────┘  └─────┬──────┘             │
│      └───────────┴───────────┴──────────────┘                    │
│                                                                  │
│  VLAN 40 - Games (192.168.40.0/24)                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                  │
│  │.11 Satisf  │  │.20 Mumble  │  │.18 Lancache│                  │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘                  │
│        └───────────────┼────────────────┘                        │
│                        │                                         │
│              Per-VLAN Gateways (.1)                               │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                      ┌────┴────┐
                      │Internet │
                      └────┬────┘
                           │
                  ┌────────┴────────┐
                  │ Tailscale Cloud │
                  │  Coordination   │
                  └────────┬────────┘
                           │
               VPN Mesh (100.64.0.0/10)
             All VMs + Remote Clients
```

## Firewall Configuration (UFW)

After Phase 4 deployment, UFW firewall is active on all VMs.

### Firewall Philosophy

**SSH Access**:

- ✅ Allowed: Tailscale network (100.64.0.0/10)
- ❌ Blocked: Direct IP access from internet
- ✅ Allowed: Management VLAN (192.168.10.0/24)

**Service Ports**:

- ✅ Allowed: Own VLAN + Management VLAN + Tailscale
- ❌ Blocked: Direct internet access (unless specifically needed)

### Per-VM Firewall Rules

#### Home Assistant (192.168.20.10) - IoT VLAN 20

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Home Assistant Web UI (IoT VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.20.0/24 to any port 8123 proto tcp comment 'Home Assistant (IoT VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8123 proto tcp comment 'Home Assistant (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8123 proto tcp comment 'Home Assistant (Tailscale)'
```

#### Satisfactory Server (192.168.40.11) - Games VLAN 40

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Satisfactory Game Ports (public - required for player connections)
sudo ufw allow 7777/udp comment 'Satisfactory Game'
sudo ufw allow 15000/udp comment 'Satisfactory Query'
sudo ufw allow 15777/udp comment 'Satisfactory Beacon'
```

#### Mumble (192.168.40.20) - Games VLAN 40

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Mumble Voice Server (Games VLAN + Tailscale)
sudo ufw allow from 192.168.40.0/24 to any port 64738 proto tcp comment 'Mumble TCP (Games VLAN)'
sudo ufw allow from 192.168.40.0/24 to any port 64738 proto udp comment 'Mumble UDP (Games VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 64738 proto tcp comment 'Mumble TCP (Tailscale)'
sudo ufw allow from 100.64.0.0/10 to any port 64738 proto udp comment 'Mumble UDP (Tailscale)'
```

#### Jellyfin (192.168.30.12) - Media VLAN 30

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Jellyfin Web UI (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 8096 proto tcp comment 'Jellyfin (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8096 proto tcp comment 'Jellyfin (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8096 proto tcp comment 'Jellyfin (Tailscale)'

# Optional: DLNA discovery (Media VLAN only)
sudo ufw allow from 192.168.30.0/24 to any port 1900 proto udp comment 'Jellyfin DLNA (Media VLAN)'
sudo ufw allow from 192.168.30.0/24 to any port 7359 proto udp comment 'Jellyfin Discovery (Media VLAN)'
```

#### Media Services (192.168.30.13) - Media VLAN 30

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Sonarr (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 8989 proto tcp comment 'Sonarr (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8989 proto tcp comment 'Sonarr (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8989 proto tcp comment 'Sonarr (Tailscale)'

# Radarr (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 7878 proto tcp comment 'Radarr (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 7878 proto tcp comment 'Radarr (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 7878 proto tcp comment 'Radarr (Tailscale)'

# Prowlarr (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 9696 proto tcp comment 'Prowlarr (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 9696 proto tcp comment 'Prowlarr (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 9696 proto tcp comment 'Prowlarr (Tailscale)'

# Jellyseerr (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 5055 proto tcp comment 'Jellyseerr (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 5055 proto tcp comment 'Jellyseerr (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 5055 proto tcp comment 'Jellyseerr (Tailscale)'

# Byparr (localhost only - no rule needed)
```

#### Download Clients (192.168.30.14) - Media VLAN 30

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# qBittorrent Web UI (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 8080 proto tcp comment 'qBittorrent (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8080 proto tcp comment 'qBittorrent (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8080 proto tcp comment 'qBittorrent (Tailscale)'

# qBittorrent Incoming (torrents - public)
sudo ufw allow 6881/tcp comment 'qBittorrent TCP'
sudo ufw allow 6881/udp comment 'qBittorrent UDP'

# SABnzbd Web UI (Media VLAN + Management VLAN + Tailscale)
sudo ufw allow from 192.168.30.0/24 to any port 8081 proto tcp comment 'SABnzbd (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8081 proto tcp comment 'SABnzbd (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8081 proto tcp comment 'SABnzbd (Tailscale)'
```

#### NAS (192.168.30.15) - Media VLAN 30

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# NFS (Media VLAN + Games VLAN for lancache)
sudo ufw allow from 192.168.30.0/24 to any port 2049 proto tcp comment 'NFS (Media VLAN)'
sudo ufw allow from 192.168.40.0/24 to any port 2049 proto tcp comment 'NFS (Games VLAN - lancache)'

# AdGuard Home Web UI (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 80 proto tcp comment 'AdGuard Home Web UI (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 80 proto tcp comment 'AdGuard Home Web UI (Tailscale)'

# AdGuard Home DNS (all VLANs + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 53 comment 'AdGuard Home DNS (Management VLAN)'
sudo ufw allow from 192.168.20.0/24 to any port 53 comment 'AdGuard Home DNS (IoT VLAN)'
sudo ufw allow from 192.168.30.0/24 to any port 53 comment 'AdGuard Home DNS (Media VLAN)'
sudo ufw allow from 192.168.40.0/24 to any port 53 comment 'AdGuard Home DNS (Games VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 53 comment 'AdGuard Home DNS (Tailscale)'
```

#### Monitoring (192.168.10.16) - Management VLAN 10

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Grafana Web UI (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 3000 proto tcp comment 'Grafana (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 3000 proto tcp comment 'Grafana (Tailscale)'

# Prometheus (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 9090 proto tcp comment 'Prometheus (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 9090 proto tcp comment 'Prometheus (Tailscale)'
```

#### Woodpecker CI (192.168.10.17) - Management VLAN 10

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Woodpecker Web UI (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 8000 proto tcp comment 'Woodpecker (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8000 proto tcp comment 'Woodpecker (Tailscale)'
```

#### Lancache (192.168.40.18) - Games VLAN 40

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Lancache HTTP/HTTPS (Games VLAN)
sudo ufw allow from 192.168.40.0/24 to any port 80 proto tcp comment 'Lancache HTTP (Games VLAN)'
sudo ufw allow from 192.168.40.0/24 to any port 443 proto tcp comment 'Lancache HTTPS (Games VLAN)'
```

#### UniFi Controller (192.168.10.19) - Management VLAN 10

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# UniFi Web UI (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 8443 proto tcp comment 'UniFi Web UI (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8443 proto tcp comment 'UniFi Web UI (Tailscale)'

# UniFi Device Communication (Management VLAN)
sudo ufw allow from 192.168.10.0/24 to any port 8080 proto tcp comment 'UniFi Inform (Management VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 3478 proto udp comment 'UniFi STUN (Management VLAN)'
```

### Managing Firewall Rules

**View current rules**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw status numbered"
```

**Add new rule**:

```bash
sudo ufw allow 9999/tcp comment 'New Service'
```

**Delete rule by number**:

```bash
sudo ufw delete 5
```

**Reload firewall**:

```bash
sudo ufw reload
```

**Disable firewall (emergency)**:

```bash
sudo ufw disable
```

## Tailscale Configuration

### Installation

Tailscale is installed during Phase 2 deployment on all VMs.

**Manual installation** (if needed):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey=tskey-api-xxxxx
```

### Tailscale Features

**SSH Access**:
After Phase 4, SSH is accessible via Tailscale or local network:

```bash
# Via Tailscale (preferred)
ssh ansible@media-services.discus-moth.ts.net

# Via local network (fallback for Tailscale outages)
ssh ansible@192.168.30.13
```

**Ephemeral Keys**:
VMs use ephemeral auth keys that:

- Automatically expire when VM is destroyed
- Don't require manual deauthorization
- Reduce security risk

**Auto-Approval**:
VMs automatically join the Tailscale network without manual approval using API-generated keys.

### Tailscale Management

**Check status**:

```bash
sudo tailscale status
```

**View IP addresses**:

```bash
sudo tailscale ip
```

**Check connectivity**:

```bash
sudo tailscale ping nas.discus-moth.ts.net
```

**Rejoin network** (if needed):

```bash
sudo tailscale up
```

**Leave network**:

```bash
sudo tailscale logout
```

### Tailscale ACLs

For advanced access control, configure ACLs in Tailscale admin console.

Example ACL for auto-approval:

```json
{
  "tagOwners": {
    "tag:homelab": ["your-email@example.com"]
  },
  "autoApprovers": {
    "routes": {
      "192.168.10.0/24": ["tag:homelab"],
      "192.168.20.0/24": ["tag:homelab"],
      "192.168.30.0/24": ["tag:homelab"],
      "192.168.40.0/24": ["tag:homelab"],
      "192.168.50.0/24": ["tag:homelab"]
    }
  }
}
```

See [reference/tailscale-auto-approval.md](../reference/tailscale-auto-approval.md) for details.

## Network Segmentation

### Why Segmentation?

**Security**: Isolate services by function
**Performance**: Reduce broadcast traffic
**Management**: Easier to apply per-VLAN policies

### Current VLAN Segmentation

**Physical Segmentation**: VLAN tagging via UniFi managed switch
**Logical Segmentation**: By VLAN, VM placement, and firewall rules

This replaces the former flat 192.168.0.0/24 network that was used prior to
the Feb 2026 VLAN migration.

**VLAN Definitions**:

| VLAN ID | Name | Subnet | VMs |
|---------|------|--------|-----|
| 10 | Management | 192.168.10.0/24 | Monitoring, Woodpecker CI, UniFi Controller |
| 20 | IoT | 192.168.20.0/24 | Home Assistant |
| 30 | Media | 192.168.30.0/24 | NAS, Jellyfin, Media Services, Download Clients |
| 40 | Games | 192.168.40.0/24 | Satisfactory, Mumble, Lancache |
| 50 | Cameras | 192.168.50.0/24 | Reserved for future use |

**Inter-VLAN Policy**:

- Management VLAN (10) can reach all other VLANs for administration
- Media VLAN (30) is self-contained for NFS and media workflows
- Games VLAN (40) can reach NAS on Media VLAN (30) for lancache storage
- IoT VLAN (20) is isolated except for Management VLAN access
- All VLANs can reach Tailscale (100.64.0.0/10) for remote access

**Network Implementation**:

```yaml
# In playbooks/vars.yml (per-VM VLAN assignment)
vm_network_vlan: 30  # Example: Media VLAN for Jellyfin
```

## DNS Configuration

### DNS Architecture Overview

**Two-Tier DNS Stack** (AdGuard Home + Unbound):

```text
Clients → AdGuard Home → Unbound → Root Servers → TLD → Authoritative
          (filtering)    (recursive)
          Port 53        Port 5335
          192.168.30.15
```

### AdGuard Home (DNS Filtering Layer)

**Deployment**: AdGuard Home runs on NAS VM (192.168.30.15)

**Purpose**:

- Network-wide ad blocking and privacy protection
- Query logging and statistics
- Integration with Tailscale MagicDNS
- Local caching (first-tier cache)

**Configuration**:

- **Primary DNS**: NAS IP (192.168.30.15 / nas.discus-moth.ts.net)
- **Web UI**: http://nas.discus-moth.ts.net:80
- **Configured via**: Tailscale Admin Console → DNS → Custom nameserver

**Upstream Resolvers** (in priority order):

1. **Tailscale MagicDNS**: `[/ts.net/]100.100.100.100` (for `*.ts.net` domains only)
2. **Local Unbound**: `127.0.0.1:5335` (primary recursive resolver)
3. **Quad9 DoT**: `tls://dns.quad9.net` (fallback if Unbound fails)
4. **Cloudflare DoT**: `tls://1dot1dot1dot1.cloudflare-dns.com` (secondary fallback)

**See Also**: [AdGuard Home Configuration Guide](adguard-home.md)

### Unbound (Recursive DNS Resolver)

**Deployment**: Unbound runs alongside AdGuard Home on NAS VM (192.168.30.15)

**Purpose**:

- True recursive DNS resolution (queries root servers directly)
- DNSSEC validation for enhanced security
- Query minimization (QNAME) for privacy
- Local caching (second-tier cache)
- Eliminates third-party DNS provider dependencies

**Configuration**:

- **Listen Address**: 0.0.0.0:5335 (accessible from localhost and local network)
- **Docker Container**: `madnuttah/unbound:latest`
- **Resource Limits**: 256MB RAM, 0.5 CPU cores
- **Actual Usage**: ~12-15MB RAM, <0.1% CPU

**Key Features**:

- **DNSSEC Validation**: Automatic trust anchor updates
- **Privacy**: QNAME minimization, minimal responses
- **Performance**: Prefetching, aggressive caching (8MB msg / 16MB rrset)
- **Security**: Hardened configuration, unwanted reply filtering
- **Availability**: Serve-expired mode for better uptime

**Benefits Over DoT Upstreams**:

- ✅ No connection pooling errors (~25% error rate eliminated)
- ✅ No third-party logging or rate limiting
- ✅ Better performance (~30ms average query time)
- ✅ Direct queries to authoritative servers
- ✅ True DNS independence

**Management**:

```bash
# Check Unbound status
ssh ansible@nas.discus-moth.ts.net "docker ps | grep unbound"

# View logs
ssh ansible@nas.discus-moth.ts.net "docker logs unbound -f"

# Test direct query
ssh ansible@nas.discus-moth.ts.net "dig @127.0.0.1 -p 5335 google.com"

# Test DNSSEC validation
ssh ansible@nas.discus-moth.ts.net "dig @127.0.0.1 -p 5335 dnssec-failed.org"

# Check resource usage
ssh ansible@nas.discus-moth.ts.net "docker stats unbound --no-stream"
```

### Local DNS (Legacy)

**Note**: After Phase 2 deployment with AdGuard Home, VMs use AdGuard Home for DNS via Tailscale.

**Previous configuration** (set via cloud-init):

```yaml
vm_network_dns:
  - "9.9.9.9"
  - "192.168.30.1"  # Per-VLAN gateway (example: Media VLAN)
```

### Tailscale MagicDNS

**Automatic**: Tailscale provides DNS for `*.ts.net` hostnames via AdGuard Home

**Resolution Flow**:

1. Device queries `jellyfin.discus-moth.ts.net`
2. Tailscale routes query to AdGuard Home (NAS)
3. AdGuard Home forwards `*.ts.net` queries to `100.100.100.100` (MagicDNS)
4. MagicDNS resolves to Tailscale IP
5. Response returned to device

**Benefits**:

- Ad blocking for all queries (including `*.ts.net`)
- Encrypted DNS for external queries
- Query logging and statistics
- Custom filtering rules

## Port Assignments

### Standard Port Assignments

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| SSH | 22 | TCP | Management VLAN + Tailscale |
| NFS | 2049 | TCP | Media VLAN + Games VLAN |
| **AdGuard Home Web UI** | **80** | **TCP** | **Management VLAN + Tailscale** |
| **AdGuard Home DNS** | **53** | **TCP/UDP** | **All VLANs + Tailscale** |
| **Unbound DNS** | **5335** | **TCP/UDP** | **Localhost + local network** |
| Home Assistant | 8123 | TCP | IoT VLAN + Management VLAN + Tailscale |
| Satisfactory | 7777 | UDP | Public |
| Mumble | 64738 | TCP/UDP | Games VLAN + Tailscale |
| Jellyfin | 8096 | TCP | Media VLAN + Management VLAN + Tailscale |
| Sonarr | 8989 | TCP | Media VLAN + Management VLAN + Tailscale |
| Radarr | 7878 | TCP | Media VLAN + Management VLAN + Tailscale |
| Prowlarr | 9696 | TCP | Media VLAN + Management VLAN + Tailscale |
| Jellyseerr | 5055 | TCP | Media VLAN + Management VLAN + Tailscale |
| Byparr | 8191 | TCP | Localhost only |
| qBittorrent Web | 8080 | TCP | Media VLAN + Management VLAN + Tailscale |
| qBittorrent Incoming | 6881 | TCP/UDP | Public |
| SABnzbd | 8081 | TCP | Media VLAN + Management VLAN + Tailscale |
| Grafana | 3000 | TCP | Management VLAN + Tailscale |
| Prometheus | 9090 | TCP | Management VLAN + Tailscale |
| Woodpecker CI | 8000 | TCP | Management VLAN + Tailscale |
| Lancache HTTP | 80 | TCP | Games VLAN |
| Lancache HTTPS | 443 | TCP | Games VLAN |
| UniFi Web UI | 8443 | TCP | Management VLAN + Tailscale |

### Port Conflicts

**Avoiding Conflicts**:

- Each service has unique port
- Docker containers use internal ports
- Host ports mapped via Docker Compose

**Checking Port Usage**:

```bash
sudo netstat -tuln | grep LISTEN
```

## Network Security Best Practices

### 1. SSH Hardening

✅ **Implemented**:

- Key-based authentication only
- SSH from Tailscale + local network (LAN fallback)
- No password authentication

❌ **Not Implemented** (consider if needed):

- Fail2ban for brute force protection
- Custom SSH port (obscurity)

### 2. Service Exposure

✅ **Current Practice**:

- Services accessible from own VLAN + Management VLAN
- Remote access via Tailscale VPN (external) or VLAN (local)
- No direct internet exposure

### 3. Firewall Management

✅ **Best Practices**:

- Default deny, explicit allow
- Minimal port exposure
- Regular rule review

### 4. VPN Security

✅ **Tailscale Benefits**:

- End-to-end encrypted (WireGuard)
- Automatic key rotation
- NAT traversal (no port forwarding needed)

## Troubleshooting

### Can't SSH to VM

**Problem**: Connection times out or refused

**Solution**:

```bash
# Use Tailscale hostname, not IP
ssh ansible@media-services.discus-moth.ts.net

# Check Tailscale is running on workstation
tailscale status

# Check firewall on VM
ssh ansible@media-services.discus-moth.ts.net "sudo ufw status"

# Verify SSH service
ssh ansible@media-services.discus-moth.ts.net "systemctl status sshd"
```

### Service Not Accessible

**Problem**: Can't reach web UI

**Solution**:

```bash
# Check service is running
docker ps  # For Docker services
systemctl status jellyfin  # For native services

# Check firewall allows port
sudo ufw status | grep 8989

# Test from VM itself
curl -I http://localhost:8989

# Check which network you're on
# Local VLAN (192.168.{10,20,30,40}.x) or Tailscale (100.x.x.x)
```

### Tailscale Not Connected

**Problem**: VM not showing in `tailscale status`

**Solution**:

```bash
# Check Tailscale service
sudo systemctl status tailscaled

# Check logs
sudo journalctl -u tailscaled -n 50

# Rejoin network
sudo tailscale up

# Verify auth key hasn't expired
# Check Tailscale admin console
```

### NFS Performance: Local IP vs Tailscale

**Problem**: NFS throughput limited to ~70 Mbps when using Tailscale hostname

**Cause**:
When mounting NFS using Tailscale hostnames (e.g., `nas.discus-moth.ts.net`), traffic routes
through the Tailscale WireGuard tunnel. This adds encryption overhead that significantly
limits throughput compared to direct local network access.

**Evidence** (from lancache deployment):

```text
# Tailscale path (slow):
clientaddr=100.107.204.114  ← Via Tailscale
addr=100.65.73.89           ← NAS via Tailscale
Result: ~70 Mbps throughput, 31% iowait

# Local network path (fast):
clientaddr=192.168.40.18    ← Direct VLAN (Games)
addr=192.168.30.15          ← NAS direct (Media VLAN)
Result: Full 10Gbps throughput
```

**When to Use Local IP for NFS**:

| Use Case | Recommendation | Reason |
|----------|----------------|--------|
| High-throughput (lancache, media) | **Local IP** | Performance critical |
| Low-throughput (config files) | Tailscale OK | Convenience, security |
| Remote/external clients | Tailscale only | Not on local network |
| VMs on same physical host | **Local IP** | Maximum performance |

**Services using local IP for NFS:**

- **All media VMs** (Jellyfin, Media Services, Download Clients): Use `192.168.30.15` for media storage
- **LANCache**: Uses `192.168.30.15` for game cache storage (requires ~140x higher throughput than
  Tailscale provides)

**Implementation** (from `host_vars/lancache.yml`):

```yaml
# NFS mount uses direct VLAN IP for full 10Gbps LAN speed
# Using Tailscale hostname (nas.discus-moth.ts.net) would limit throughput
# to ~70 Mbps due to WireGuard tunnel encryption overhead.
# Cross-VLAN NFS access is permitted by inter-VLAN routing policy.
nfs_server: "192.168.30.15"
```

**Security Note**: Using VLAN IPs is safe for VMs on the same physical host.
The NFS server firewall (UFW) restricts NFS access to the Media VLAN
(192.168.30.0/24) and Games VLAN (192.168.40.0/24) only.

### NFS Mount Fails

**Problem**: Can't mount NFS share

**Solution**:

```bash
# Check NFS server is running
ssh ansible@nas.discus-moth.ts.net "sudo systemctl status nfs-server"

# Verify exports
ssh ansible@nas.discus-moth.ts.net "sudo exportfs -v"

# Check firewall allows NFS
ssh ansible@nas.discus-moth.ts.net "sudo ufw status | grep 2049"

# Test mount manually (use direct VLAN IP for NFS reliability)
sudo mount -t nfs 192.168.30.15:/mnt/storage/data /mnt/test
```

> **Note**: NFS mounts use direct VLAN IP (192.168.30.15) rather than Tailscale hostname to avoid
> tunnel saturation under heavy I/O. See [NFS Performance: Local IP vs Tailscale](#nfs-performance-local-ip-vs-tailscale)
> and [NFS Direct IP Migration](../reference/nfs-direct-ip-migration.md).

### Firewall Locked Me Out

**Problem**: Can't access any services

**Solution**:

```bash
# Access via Proxmox console
ssh root@jellybuntu.discus-moth.ts.net
qm terminal <vmid>

# Login and check/disable firewall
sudo ufw status
sudo ufw disable  # Emergency only

# Review and fix rules
sudo ufw status numbered
sudo ufw delete <bad-rule-number>
sudo ufw enable
```

### DNS Resolution Issues

**Problem**: Slow DNS or resolution failures

**Solution**:

```bash
# Check AdGuard Home is running
ssh ansible@nas.discus-moth.ts.net "docker ps | grep adguard"

# Check Unbound is running
ssh ansible@nas.discus-moth.ts.net "docker ps | grep unbound"

# Test Unbound directly
ssh ansible@nas.discus-moth.ts.net "dig @127.0.0.1 -p 5335 google.com"

# Test AdGuard Home
ssh ansible@nas.discus-moth.ts.net "dig @192.168.30.15 google.com"

# Check AdGuard Home logs for upstream errors
ssh ansible@nas.discus-moth.ts.net "docker logs adguardhome --tail 50 | grep -i error"

# Check Unbound logs
ssh ansible@nas.discus-moth.ts.net "docker logs unbound --tail 50"

# Restart AdGuard if needed
ssh ansible@nas.discus-moth.ts.net "cd /opt/adguard-home && docker compose restart"

# Restart Unbound if needed
ssh ansible@nas.discus-moth.ts.net "cd /opt/unbound && docker compose restart"
```

**Problem**: DNSSEC validation failures

**Solution**:

```bash
# Test DNSSEC validation
ssh ansible@nas.discus-moth.ts.net "dig @127.0.0.1 -p 5335 +dnssec google.com"

# Check if DNSSEC is blocking legitimate domains
ssh ansible@nas.discus-moth.ts.net "docker logs unbound | grep 'validation failure'"

# Temporarily disable DNSSEC (emergency only)
# Edit /opt/unbound/config/unbound.conf and set:
# module-config: "iterator"
# Then restart Unbound
```

**Problem**: Unbound not responding

**Solution**:

```bash
# Check if Unbound container is healthy
ssh ansible@nas.discus-moth.ts.net "docker inspect unbound | grep -A 10 Health"

# Check resource usage
ssh ansible@nas.discus-moth.ts.net "docker stats unbound --no-stream"

# Verify configuration
ssh ansible@nas.discus-moth.ts.net "cat /opt/unbound/config/unbound.conf"

# Restart Unbound
ssh ansible@nas.discus-moth.ts.net "cd /opt/unbound && docker compose restart"

# If Unbound continues failing, AdGuard will automatically failover to DoT upstreams (Quad9/Cloudflare)
```

## Configuration Files

### UFW Rules Location

Rules defined in [`host_vars/<vm-name>.yml`](https://github.com/SilverDFlame/jellybuntu/tree/main/host_vars):

```yaml
firewall_ports:
  - { port: 8989, proto: tcp, comment: "Sonarr" }
  - { port: 7878, proto: tcp, comment: "Radarr" }
```

### Network Configuration

VM network settings in [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml):

```yaml
# Gateway and DNS are VLAN-specific (set per-VM or per-VLAN group)
# Examples:
#   Management VLAN: vm_network_gateway: "192.168.10.1"
#   IoT VLAN:        vm_network_gateway: "192.168.20.1"
#   Media VLAN:      vm_network_gateway: "192.168.30.1"
#   Games VLAN:      vm_network_gateway: "192.168.40.1"
vm_network_dns:
  - "9.9.9.9"
  - "{{ vm_network_gateway }}"  # Per-VLAN gateway as secondary DNS
```

### Tailscale Configuration

Tailscale API key in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml):

```yaml
vault_tailscale_api_key: "tskey-api-xxxxx"
```

## Reference

- [Service Endpoints](service-endpoints.md) - All service URLs and ports
- [Security Configuration](security.md) - Security best practices
- [Tailscale Auto-Approval](../reference/tailscale-auto-approval.md) - ACL configuration
- UFW Firewall Role ([`roles/ufw_firewall/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/ufw_firewall/)) - Firewall automation
- [Architecture Overview](../architecture.md) - Network design

## Summary

**Network Design**:

- VLAN-segmented local network (Management, IoT, Media, Games) + Tailscale VPN
- Static IP assignments for all 11 VMs across 4 active VLANs
- Per-VLAN gateways and DNS configuration
- Replaced former flat 192.168.0.0/24 network in Feb 2026

**Security**:

- SSH restricted to Management VLAN (192.168.10.0/24) + Tailscale
- Service access scoped to own VLAN + Management VLAN + Tailscale
- UFW firewall on all VMs with VLAN-aware rules
- End-to-end encryption via WireGuard for remote access

**Management**:

- Centralized firewall rules via Ansible
- Tailscale for secure remote access
- NFS for shared storage (Media VLAN + Games VLAN cross-VLAN access)
- UniFi Controller on Management VLAN for network device management
