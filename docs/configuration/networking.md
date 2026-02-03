# Networking Configuration

Complete guide to network architecture, firewall rules, and Tailscale VPN configuration.

## Overview

The Jellybuntu infrastructure uses a dual-network approach:

- **Local Network** (192.168.0.0/24): Direct LAN access
- **Tailscale VPN** (100.64.0.0/10): Secure remote access

This provides both local performance and secure remote connectivity.

## Network Architecture

### Local Network (192.168.0.0/24)

**Purpose**: Primary network for all services

**Configuration**:

- **Subnet**: 192.168.0.0/24
- **Gateway**: 192.168.0.1
- **DNS Primary**: 9.9.9.9 (Quad9)
- **DNS Secondary**: 192.168.0.1 (Local router)

**IP Allocations**:

| Device | IP | Hostname | Purpose |
|--------|-----|----------|---------|
| Proxmox Host | Varies | jellybuntu.discus-moth.ts.net | Hypervisor |
| Home Assistant | 192.168.0.10 | home-assistant | Automation |
| Satisfactory | 192.168.0.11 | satisfactory-server | Game server |
| Jellyfin | 192.168.0.12 | jellyfin | Media streaming |
| Media Services | 192.168.0.13 | media-services | Sonarr/Radarr/etc |
| Download Clients | 192.168.0.14 | download-clients | qBittorrent/SABnzbd |
| NAS | 192.168.0.15 | nas | Storage server |

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
- `jellyfin.discus-moth.ts.net`
- `media-services.discus-moth.ts.net`
- `download-clients.discus-moth.ts.net`
- `nas.discus-moth.ts.net`

### Network Flow Diagram

```text
┌─────────────────────────────────────────────────────────┐
│ Local Network (192.168.0.0/24)                          │
│                                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │
│  │ .10  │  │ .11  │  │ .12  │  │ .13  │  │ .14  │      │
│  │HA    │  │ Satis│  │Jelly │  │Media │  │Downl │      │
│  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘      │
│     │         │         │         │         │           │
│     └─────────┴─────────┴─────────┴─────────┘           │
│                         │                                │
│                    ┌────┴────┐                           │
│                    │ .15 NAS │                           │
│                    │  (NFS)  │                           │
│                    └─────────┘                           │
│                                                          │
│                    Gateway .1                            │
└────────────────────────┬─────────────────────────────────┘
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
- ✅ Allowed: Local network (192.168.0.0/24) - optional

**Service Ports**:

- ✅ Allowed: Local network + Tailscale
- ❌ Blocked: Direct internet access (unless specifically needed)

### Per-VM Firewall Rules

#### Home Assistant (192.168.0.10)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp comment 'SSH (LAN)'

# Home Assistant Web UI
sudo ufw allow 8123/tcp comment 'Home Assistant'
```

#### Satisfactory Server (192.168.0.11)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp

# Satisfactory Game Ports
sudo ufw allow 7777/udp comment 'Satisfactory Game'
sudo ufw allow 15000/udp comment 'Satisfactory Query'
sudo ufw allow 15777/udp comment 'Satisfactory Beacon'
```

#### Jellyfin (192.168.0.12)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp

# Jellyfin Web UI
sudo ufw allow 8096/tcp comment 'Jellyfin'

# Optional: DLNA discovery
sudo ufw allow 1900/udp comment 'Jellyfin DLNA'
sudo ufw allow 7359/udp comment 'Jellyfin Discovery'
```

#### Media Services (192.168.0.13)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp

# Sonarr
sudo ufw allow 8989/tcp comment 'Sonarr'

# Radarr
sudo ufw allow 7878/tcp comment 'Radarr'

# Prowlarr
sudo ufw allow 9696/tcp comment 'Prowlarr'

# Jellyseerr
sudo ufw allow 5055/tcp comment 'Jellyseerr'

# Flaresolverr (localhost only - no rule needed)
```

#### Download Clients (192.168.0.14)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp

# qBittorrent Web UI
sudo ufw allow 8080/tcp comment 'qBittorrent Web UI'

# qBittorrent Incoming (torrents)
sudo ufw allow 6881/tcp comment 'qBittorrent TCP'
sudo ufw allow 6881/udp comment 'qBittorrent UDP'

# SABnzbd Web UI
sudo ufw allow 8081/tcp comment 'SABnzbd'
```

#### NAS (192.168.0.15)

```bash
# SSH (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp
sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp

# NFS (local network only for security)
sudo ufw allow from 192.168.0.0/24 to any port 2049 proto tcp comment 'NFS'

# AdGuard Home Web UI (Tailscale + LAN)
sudo ufw allow from 100.64.0.0/10 to any port 80 proto tcp comment 'AdGuard Home Web UI (Tailscale)'
sudo ufw allow from 192.168.0.0/24 to any port 80 proto tcp comment 'AdGuard Home Web UI (LAN)'

# AdGuard Home DNS (local network)
sudo ufw allow from 192.168.0.0/24 to any port 53 proto tcp comment 'AdGuard Home DNS (LAN)'
sudo ufw allow from 192.168.0.0/24 to any port 53 proto udp comment 'AdGuard Home DNS (LAN)'

# AdGuard Home DNS (Tailscale)
sudo ufw allow from 100.64.0.0/10 to any port 53 proto tcp comment 'AdGuard Home DNS (Tailscale)'
sudo ufw allow from 100.64.0.0/10 to any port 53 proto udp comment 'AdGuard Home DNS (Tailscale)'
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
ssh ansible@192.168.0.13
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
      "192.168.0.0/24": ["tag:homelab"]
    }
  }
}
```

See [reference/tailscale-auto-approval.md](../reference/tailscale-auto-approval.md) for details.

## Network Segmentation

### Why Segmentation?

**Security**: Isolate services by function
**Performance**: Reduce broadcast traffic
**Management**: Easier to apply policies

### Current Segmentation Strategy

**Physical Segmentation**: None (all on same VLAN)
**Logical Segmentation**: By VM and firewall rules

**Service Groups**:

1. **Infrastructure**: NAS, Proxmox
2. **Home Automation**: Home Assistant
3. **Game Servers**: Satisfactory
4. **Media Management**: Media Services VM
5. **Download Operations**: Download Clients VM
6. **Media Streaming**: Jellyfin

### Future Segmentation Options

If more isolation is needed:

**VLAN Segmentation**:

- VLAN 10: Management (Proxmox, NAS)
- VLAN 20: Services (Media, Downloads)
- VLAN 30: DMZ (Jellyfin, public-facing)

**Network Implementation**:

```yaml
# In playbooks/vars.yml
vm_network_vlan: 20
```

## DNS Configuration

### DNS Architecture Overview

**Two-Tier DNS Stack** (AdGuard Home + Unbound):

```text
Clients → AdGuard Home → Unbound → Root Servers → TLD → Authoritative
          (filtering)    (recursive)
          Port 53        Port 5335
          192.168.0.15
```

### AdGuard Home (DNS Filtering Layer)

**Deployment**: AdGuard Home runs on NAS VM (192.168.0.15)

**Purpose**:

- Network-wide ad blocking and privacy protection
- Query logging and statistics
- Integration with Tailscale MagicDNS
- Local caching (first-tier cache)

**Configuration**:

- **Primary DNS**: NAS IP (192.168.0.15 / nas.discus-moth.ts.net)
- **Web UI**: http://nas.discus-moth.ts.net:80
- **Configured via**: Tailscale Admin Console → DNS → Custom nameserver

**Upstream Resolvers** (in priority order):

1. **Tailscale MagicDNS**: `[/ts.net/]100.100.100.100` (for `*.ts.net` domains only)
2. **Local Unbound**: `127.0.0.1:5335` (primary recursive resolver)
3. **Quad9 DoT**: `tls://dns.quad9.net` (fallback if Unbound fails)
4. **Cloudflare DoT**: `tls://1dot1dot1dot1.cloudflare-dns.com` (secondary fallback)

**See Also**: [AdGuard Home Configuration Guide](adguard-home.md)

### Unbound (Recursive DNS Resolver)

**Deployment**: Unbound runs alongside AdGuard Home on NAS VM (192.168.0.15)

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
  - "192.168.0.1"
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
| SSH | 22 | TCP | Tailscale + LAN |
| NFS | 2049 | TCP | Local only |
| **AdGuard Home Web UI** | **80** | **TCP** | **Tailscale + LAN** |
| **AdGuard Home DNS** | **53** | **TCP/UDP** | **Local + Tailscale** |
| **Unbound DNS** | **5335** | **TCP/UDP** | **Localhost + Local network** |
| Home Assistant | 8123 | TCP | Local + Tailscale |
| Satisfactory | 7777 | UDP | Public |
| Jellyfin | 8096 | TCP | Local + Tailscale |
| Sonarr | 8989 | TCP | Local + Tailscale |
| Radarr | 7878 | TCP | Local + Tailscale |
| Prowlarr | 9696 | TCP | Local + Tailscale |
| Jellyseerr | 5055 | TCP | Local + Tailscale |
| Flaresolverr | 8191 | TCP | Localhost only |
| qBittorrent Web | 8080 | TCP | Local + Tailscale |
| qBittorrent Incoming | 6881 | TCP/UDP | Public |
| SABnzbd | 8081 | TCP | Local + Tailscale |

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

- Services accessible from local network
- Remote access via Tailscale VPN (external) or LAN (local)
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
# Local (192.168.0.x) or Tailscale (100.x.x.x)
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
clientaddr=192.168.0.18     ← Direct LAN
addr=192.168.0.15           ← NAS direct
Result: Full 10Gbps throughput
```

**When to Use Local IP for NFS**:

| Use Case | Recommendation | Reason |
|----------|----------------|--------|
| High-throughput (lancache, media) | **Local IP** | Performance critical |
| Low-throughput (config files) | Tailscale OK | Convenience, security |
| Remote/external clients | Tailscale only | Not on local network |
| VMs on same physical host | **Local IP** | Maximum performance |

**Implementation**:

```yaml
# host_vars/lancache.yml - Use local IP for performance
lancache_nfs_server: "192.168.0.15"  # NOT nas.discus-moth.ts.net

# host_vars/media-services.yml - Tailscale OK for lower throughput
nfs_server: "nas.discus-moth.ts.net"  # Convenience over performance
```

**Security Note**: Using local IPs is safe for VMs on the same physical network.
The NFS server firewall (UFW) restricts NFS access to 192.168.0.0/24 regardless
of which hostname/IP is used to connect.

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

# Test mount manually (use direct IP for NFS reliability)
sudo mount -t nfs 192.168.0.15:/mnt/storage/data /mnt/test
```

> **Note**: NFS mounts use direct IP (192.168.0.15) rather than Tailscale hostname to avoid
> tunnel saturation under heavy I/O. See [NFS Direct IP Migration](../reference/nfs-direct-ip-migration.md).

### NFS Performance: Local IP vs Tailscale

For high-throughput NFS workloads, using local IP addresses instead of Tailscale hostnames provides significant performance improvements:

| Connection Type | Throughput | Use Case |
|-----------------|------------|----------|
| Tailscale hostname | ~70 Mbps | Low-bandwidth, remote access |
| Local IP (192.168.0.x) | Full LAN speed (1-10 Gbps) | High-throughput local services |

**Why the difference?**

- Tailscale encrypts all traffic through a WireGuard tunnel
- Encryption overhead becomes significant under sustained heavy I/O
- Local IP bypasses the tunnel for VMs on the same physical network

**Services using local IP for NFS:**

- **All media VMs** (Jellyfin, Media Services, Download Clients): Use `192.168.0.15` for media storage
- **LANCache**: Uses `192.168.0.15` for game cache storage (requires ~140x higher throughput than Tailscale provides)

**Configuration example** (from `host_vars/lancache.yml`):

```yaml
# NFS mount uses direct local IP for full 10Gbps LAN speed
# Using Tailscale hostname (nas.discus-moth.ts.net) would limit throughput
# to ~70 Mbps due to WireGuard tunnel encryption overhead.
# Local IP is safe because both VMs are on the same physical network.
nfs_server: "192.168.0.15"
```

**Security note**: Using local IP is safe for VMs on the same physical network segment. External access still requires Tailscale VPN.

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
ssh ansible@nas.discus-moth.ts.net "dig @192.168.0.15 google.com"

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
vm_network_gateway: "192.168.0.1"
vm_network_dns:
  - "9.9.9.9"
  - "192.168.0.1"
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

- Dual network: Local (192.168.0.0/24) + Tailscale VPN
- Static IP assignments for all VMs
- Consistent DNS configuration

**Security**:

- SSH via Tailscale + LAN after Phase 4
- UFW firewall on all VMs
- Minimal port exposure
- End-to-end encryption via WireGuard

**Management**:

- Centralized firewall rules via Ansible
- Tailscale for secure remote access
- NFS for shared storage (local network only)

Your network is secure, performant, and maintainable!
