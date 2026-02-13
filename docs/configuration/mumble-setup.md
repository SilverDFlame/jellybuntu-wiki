# Mumble Server Configuration

Mumble is a low-latency, high-quality voice chat application. This guide covers the dedicated server
setup for the Jellybuntu homelab.

> **IMPORTANT**: Mumble runs as a **rootless Podman container with Quadlet** on the mumble VM
> (192.168.40.20). Use `systemctl --user` commands.

## Overview

- **VM**: mumble (VMID 201, 192.168.40.20)
- **Port**: 64738 (TCP + UDP)
- **Container**: `mumblevoip/mumble-server:v1.5.857-1`
- **Deployment**: Rootless Podman with Quadlet via `podman_app` role
- **Server Name**: Elysium
- **VLAN**: Games (40)
- **Phase**: 4 (optional service)
- **Playbook**: [`playbooks/services/mumble.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/mumble.yml)

## Resources

| Resource | Value |
|----------|-------|
| CPU Cores | 1 (shared) |
| CPU Units | 512 (low priority) |
| Memory | 1GB (1024MB) |
| Memory Reservation | 512MB |
| Disk | 32GB (local-zfs) |

## Access

- **Tailscale**: mumble.discus-moth.ts.net:64738
- **Local Network**: 192.168.40.20:64738

## Deployment

### Via Ansible Playbook (Recommended)

```bash
./bin/runtime/ansible-run.sh playbooks/services/mumble.yml
```

The playbook:

1. Deploys Mumble server container via `podman_app` role
2. Configures firewall rules (TCP/UDP 64738)
3. Sets server name and superuser password from SOPS vault
4. Enables lingering for user services

### Credentials

The superuser password is stored in the SOPS-encrypted vault:

```yaml
# In group_vars/all.sops.yaml
vault_mumble_superuser_password: "..."
```

## Client Connection

### Desktop (Mumble Client)

1. Download Mumble from [mumble.info](https://www.mumble.info/downloads/)
2. Open Mumble and click **Add New...**
3. Configure:
   - **Label**: Elysium
   - **Address**: `mumble.discus-moth.ts.net` (Tailscale) or `192.168.40.20` (local)
   - **Port**: `64738`
   - **Username**: Your preferred name
4. Click **OK**, then **Connect**

### Mobile (Mumla for Android)

1. Install **Mumla** from F-Droid or Google Play
2. Add server:
   - **Label**: Elysium
   - **Address**: `mumble.discus-moth.ts.net`
   - **Port**: `64738`
   - **Username**: Your preferred name
3. Connect

## Service Management

```bash
# SSH to mumble VM
ssh -i ~/.ssh/ansible_homelab ansible@mumble.discus-moth.ts.net

# Check service status
systemctl --user status mumble-server

# View logs
journalctl --user -u mumble-server -f

# Restart service
systemctl --user restart mumble-server

# Check container
podman ps | grep mumble
```

## Firewall Rules

```bash
# SSH (Management VLAN + Tailscale)
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment 'SSH (Management VLAN)'
sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH (Tailscale)'

# Mumble server
sudo ufw allow 64738/tcp comment 'Mumble TCP'
sudo ufw allow 64738/udp comment 'Mumble UDP'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect | Verify firewall allows TCP/UDP 64738 |
| High latency | Use Tailscale for remote, local IP for LAN |
| Server not starting | Check logs: `journalctl --user -u mumble-server` |
| Authentication failed | Verify superuser password in vault |

## See Also

- [Service Endpoints](service-endpoints.md) - All service URLs and ports
- [VM Specifications](../reference/vm-specifications.md) - VM resource allocation
- [Satisfactory Setup](satisfactory-setup.md) - Similar game server setup pattern
