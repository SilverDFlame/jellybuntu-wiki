# VLAN Migration Reference

Reference guide for the migration from flat 192.168.0.0/24 networking to VLAN-aware
Proxmox bridging with network segmentation.

## VLAN Definitions

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 10 | Management | 192.168.10.0/24 | Infrastructure services (monitoring, CI, UniFi) |
| 20 | IoT | 192.168.20.0/24 | Home automation devices |
| 30 | Media | 192.168.30.0/24 | Media services, storage, downloads |
| 40 | Games | 192.168.40.0/24 | Game servers, game caching |
| 50 | Cameras | 192.168.50.0/24 | Security cameras (reserved) |

## Complete IP Mapping

| VM | VMID | Legacy IP | VLAN IP | VLAN | Gateway |
|----|------|-----------|---------|------|---------|
| Home Assistant | 100 | 192.168.0.10 | 192.168.20.10 | IoT (20) | 192.168.20.1 |
| Satisfactory | 200 | 192.168.0.11 | 192.168.40.11 | Games (40) | 192.168.40.1 |
| Mumble | 201 | (new) | 192.168.40.20 | Games (40) | 192.168.40.1 |
| NAS | 300 | 192.168.0.15 | 192.168.30.15 | Media (30) | 192.168.30.1 |
| Jellyfin | 400 | 192.168.0.12 | 192.168.30.12 | Media (30) | 192.168.30.1 |
| Media Services | 401 | 192.168.0.13 | 192.168.30.13 | Media (30) | 192.168.30.1 |
| Download Clients | 402 | 192.168.0.14 | 192.168.30.14 | Media (30) | 192.168.30.1 |
| Monitoring | 500 | 192.168.0.16 | 192.168.10.16 | Management (10) | 192.168.10.1 |
| Woodpecker CI | 600 | 192.168.0.17 | 192.168.10.17 | Management (10) | 192.168.10.1 |
| Lancache | 700 | 192.168.0.18 | 192.168.40.18 | Games (40) | 192.168.40.1 |
| UniFi Controller | 800 | 192.168.0.19 | 192.168.10.19 | Management (10) | 192.168.10.1 |

> **Note**: NAS is on Media VLAN (30), not Management, because it serves NFS storage
> to media VMs. Co-locating NAS with its primary consumers avoids cross-VLAN NFS traffic.

## Migration Approach

The VLAN migration uses a two-phase additive approach to avoid downtime.

### Phase 1: Additive (Current)

Both legacy and VLAN firewall rules coexist on each VM:

- Legacy rules (192.168.0.0/24) remain active for backwards compatibility
- VLAN-specific rules added alongside legacy rules
- VMs are assigned VLAN IPs via Terraform/cloud-init
- Proxmox bridge (`vmbr0`) configured as VLAN-aware

This allows gradual validation without breaking existing connectivity.

### Phase 2: Cutover (Future)

Once all services are confirmed working on VLAN IPs:

- Set `ufw_remove_legacy: true` in host vars
- Re-run firewall playbook to remove legacy 192.168.0.0/24 rules
- Only VLAN-specific rules remain
- Legacy subnet no longer routable to VMs

## UFW Rule Structure

After VLAN migration, firewall rules follow this pattern:

**SSH Access**: Allowed from Management VLAN (192.168.10.0/24) + Tailscale (100.64.0.0/10):

```bash
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'
```

**Service Ports**: Allowed from own VLAN + Management VLAN + Tailscale:

```bash
# Example: Sonarr on Media Services (VLAN 30)
sudo ufw allow from 192.168.30.0/24 to any port 8989 proto tcp comment 'Sonarr (Media VLAN)'
sudo ufw allow from 192.168.10.0/24 to any port 8989 proto tcp comment 'Sonarr (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 8989 proto tcp comment 'Sonarr (Tailscale)'
```

## Cross-VLAN Access Patterns

Some services require cross-VLAN access:

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| All VLANs | NAS (192.168.30.15) | 53 | DNS (AdGuard Home) |
| All VLANs | NAS (192.168.30.15) | 80 | AdGuard Home Web UI |
| Media VLAN (30) | NAS (192.168.30.15) | 2049 | NFS media storage |
| Games VLAN (40) | NAS (192.168.30.15) | 2049 | NFS lancache storage |
| Management VLAN (10) | All VLANs | 22 | SSH administration |

### NFS IP Changes

With VLAN migration, NFS server references change:

- **NFS Server**: `192.168.30.15` (was `192.168.0.15`)
- **Lancache NFS client**: `192.168.40.18` connecting to `192.168.30.15` (cross-VLAN)
- **Media VM NFS clients**: Same VLAN as NAS (192.168.30.0/24), no cross-VLAN needed

## Proxmox Bridge Configuration

The Proxmox bridge is configured as VLAN-aware in
[`infrastructure/terraform/vms.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf):

- **Bridge**: `vmbr0` with `vlan_aware = true`
- Each VM specifies its VLAN tag in the network configuration
- Inter-VLAN routing handled by the gateway/router

## See Also

- [Architecture Overview](../architecture.md) - Infrastructure design with VLAN topology
- [Networking Configuration](../configuration/networking.md) - Firewall rules and network details
- [VM Specifications](vm-specifications.md) - Per-VM network configuration
