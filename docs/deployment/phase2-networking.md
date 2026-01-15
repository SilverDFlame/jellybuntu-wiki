# Phase 2: Networking Configuration

Configure storage infrastructure and VPN mesh network.

## Overview

Phase 2 sets up network storage (NAS with Btrfs RAID1 + NFS) and establishes the Tailscale VPN mesh connecting all VMs.

**Estimated Time**: 4-6 minutes

## Prerequisites

- ✅ Phase 1 completed successfully
- All VMs running and accessible via IP
- Tailscale API key in secrets file
- NFS UID/GID configured in secrets file

## What Phase 2 Does

### 1. Configure NAS Storage

- Creates Btrfs RAID1 array from 3x 6TB disks (~9TB usable)
- Mounts array at `/mnt/storage`
- Creates directory structure for media and downloads
- Installs and configures NFS server
- Exports `/mnt/storage/data` to client VMs

### 2. Install Tailscale on All VMs

- Installs Tailscale on all 6 VMs
- Generates ephemeral auth keys via Tailscale API
- Joins each VM to Tailscale network
- Registers Tailscale hostnames (e.g., `nas.discus-moth.ts.net`)

### 3. Deploy AdGuard Home (Internal DNS)

- Disables systemd-resolved DNS stub listener
- Deploys AdGuard Home Docker container on NAS VM
- Configures UFW firewall for DNS (port 53) and Web UI (port 80)
- Auto-configures admin credentials from vault
- Pre-configured with 3 blocklists:
  - AdGuard DNS filter (general ads and trackers)
  - AdAway Default Blocklist (mobile ads)
  - MalwareDomainList.com (malware protection)
- Configures upstream DNS servers:
  - Tailscale MagicDNS (for `*.ts.net` domains)
  - Quad9 DoT (encrypted DNS)
  - Cloudflare DoT (encrypted DNS)
- Sets blocklist auto-update to 24 hours

## Running Phase 2

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml
```

## Expected Output

```text
PLAY [Configure NAS] ***************************************************

TASK [Install btrfs-progs] *********************************************
changed: [nas]

TASK [Create Btrfs RAID1 array] ****************************************
changed: [nas]

TASK [Install NFS server] **********************************************
changed: [nas]

TASK [Configure NFS exports] *******************************************
changed: [nas]

PLAY [Install Tailscale on all VMs] ************************************

TASK [Install Tailscale] ***********************************************
changed: [home-assistant]
changed: [nas]
changed: [jellyfin]
...

TASK [Join Tailscale network] ******************************************
changed: [home-assistant]
changed: [nas]
...

PLAY RECAP *************************************************************
nas                  : ok=12 changed=10
home-assistant       : ok=5  changed=4
jellyfin             : ok=5  changed=4
...
```

## Verification

### Check Btrfs Array

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo btrfs filesystem show"
```

Expected output showing RAID1 array:

```text
Label: 'storage'  uuid: ...
    Total devices 2 FS bytes used ...
    devid    1 size 500.00GiB used ... path /dev/sdb
    devid    2 size 500.00GiB used ... path /dev/sdc
```

### Verify NFS Exports

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo exportfs -v"
```

Expected output:

```text
/mnt/storage/data
    192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### Check Tailscale Status

```bash
# From your workstation
tailscale status
```

Expected output showing all VMs:

```text
100.x.x.x   home-assistant       ...  online
100.x.x.x   nas                  ...  online
100.x.x.x   jellyfin             ...  online
100.x.x.x   media-services       ...  online
100.x.x.x   download-clients     ...  online
100.x.x.x   satisfactory-server  ...  online
```

### Test Tailscale Connectivity

```bash
# Ping VMs via Tailscale hostnames
ping nas.discus-moth.ts.net
ping jellyfin.discus-moth.ts.net
ping media-services.discus-moth.ts.net

# SSH via Tailscale (replaces IP-based SSH)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net
```

### Verify AdGuard Home Deployment

```bash
# Check AdGuard Home container is running
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "docker ps | grep adguard"
```

Expected output:

```text
CONTAINER ID   IMAGE                    STATUS       PORTS
xxxxx          adguard/adguardhome      Up 2 min     0.0.0.0:53->53/tcp, 0.0.0.0:80->80/tcp
```

**Access AdGuard Home Web UI**:

1. Navigate to http://nas.discus-moth.ts.net:80
2. Login with credentials from vault (`vault_services_admin_username` / `vault_services_admin_password`)
3. Dashboard should show:
   - 3 active blocklists
   - Upstream DNS: Quad9 DoT, Cloudflare DoT
   - DNSSEC enabled

**Test DNS Resolution**:

```bash
# Test direct DNS query to AdGuard Home
dig @nas.discus-moth.ts.net google.com

# Should return answer in ~30-50ms with NOERROR status
```

**Test MagicDNS Integration**:

```bash
# Test that *.ts.net domains resolve
dig @nas.discus-moth.ts.net jellyfin.discus-moth.ts.net

# Should resolve to Tailscale IP (100.x.x.x)
```

## NAS Directory Structure

After Phase 2, the NAS has this structure:

```text
/mnt/storage/
└── data/
    ├── media/
    │   ├── tv/
    │   └── movies/
    ├── torrents/
    │   ├── tv/
    │   ├── movies/
    │   └── incomplete/
    └── usenet/
        ├── tv/
        ├── movies/
        └── incomplete/
```

This follows TRaSH Guides recommendations for hardlink support.

## Troubleshooting

### Btrfs Array Creation Fails

**Error**: `Failed to create Btrfs filesystem`

**Solution**:

```bash
# Check disks are present
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.15 "lsblk"

# Should show sdb, sdc, sdd (6TB each)
# If missing, check Proxmox disk passthrough

# Verify disks have no existing filesystem
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.15 \
  "sudo wipefs -a /dev/sdb /dev/sdc /dev/sdd"
```

### NFS Server Won't Start

**Error**: `NFS server failed to start`

**Solution**:

```bash
# Check NFS service status
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl status nfs-server"

# View logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo journalctl -u nfs-server -n 50"

# Restart NFS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl restart nfs-server"
```

### Tailscale Installation Fails

**Error**: `Failed to install Tailscale`

**Solution**:

```bash
# Check internet connectivity from VM
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10 \
  "ping -c 3 tailscale.com"

# Check DNS resolution
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10 \
  "nslookup tailscale.com"

# Manual installation
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10
curl -fsSL https://tailscale.com/install.sh | sh
```

### Tailscale Won't Join Network

**Error**: `Failed to authenticate with Tailscale`

**Solution**:

```bash
# Verify API key in secrets file
sops -d group_vars/all.sops.yaml | grep tailscale

# Check key hasn't expired in Tailscale admin console
# Ensure key is "Reusable" and "Ephemeral"

# Try manual join
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10
sudo tailscale up --authkey=tskey-api-xxxxx
```

### VMs Not Visible in Tailscale

**Solution**:

```bash
# Check Tailscale status on VM
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo tailscale status"

# If not running, start Tailscale
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl start tailscaled"

# Check Tailscale logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo journalctl -u tailscaled -n 50"
```

### NFS Mount Permission Issues

**Error**: Permission denied on NFS share

**Solution**:

```bash
# Check NFS export options
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo exportfs -v"

# Verify UID/GID in secrets file match NFS configuration
sops -d group_vars/all.sops.yaml | grep nfs_

# Check directory permissions
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "ls -la /mnt/storage/data"

# Test NFS mount manually (use direct IP for reliability)
sudo mount -t nfs 192.168.0.15:/mnt/storage/data /mnt/test
```

> **Note**: NFS mounts use direct IP (192.168.0.15) rather than Tailscale hostname for reliability.
> See [NFS Direct IP Migration](../reference/nfs-direct-ip-migration.md).

### AdGuard Home Container Won't Start

**Error**: `AdGuard Home container exited`

**Solution**:

```bash
# Check container logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "docker logs adguardhome --tail 50"

# Check if port 53 is already in use (systemd-resolved conflict)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo lsof -i :53"

# If systemd-resolved is still using port 53:
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl disable systemd-resolved && sudo systemctl stop systemd-resolved"

# Restart AdGuard Home
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "cd /opt/adguard-home && docker compose restart"
```

### AdGuard Home Web UI Not Accessible

**Error**: Can't reach http://nas.discus-moth.ts.net:80

**Solution**:

```bash
# Check firewall allows port 80 from Tailscale
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ufw status | grep 80"

# If missing, add firewall rule
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ufw allow from 100.64.0.0/10 to any port 80 proto tcp comment 'AdGuard Home Web UI'"

# Verify Tailscale is working
ping nas.discus-moth.ts.net
curl -I http://nas.discus-moth.ts.net:80
```

### DNS Queries Not Working

**Error**: DNS queries to AdGuard Home timeout or fail

**Solution**:

```bash
# Check if container is running
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "docker ps | grep adguard"

# Check firewall allows DNS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ufw status | grep 53"

# Test DNS directly
dig @192.168.0.15 google.com

# Check AdGuard Home logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "docker logs adguardhome --tail 100"
```

## Playbook Details

**Files**:

- [`playbooks/core/02-configure-nas-role.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/02-configure-nas-role.yml) - NAS configuration
- [`playbooks/core/03-configure-tailscale-role.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/03-configure-tailscale-role.yml) - Tailscale installation
- [`playbooks/core/14-configure-adguard-home-role.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/14-configure-adguard-home-role.yml) - AdGuard Home deployment

**Roles**:

- [`roles/nas/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/nas/) - Btrfs and NFS configuration
- [`roles/tailscale/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/tailscale/) - Tailscale installation and configuration
- [`roles/adguard_home/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/adguard_home/) - AdGuard Home DNS deployment

**Variables** (from [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml) and [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml)):

- `vault_tailscale_api_key`: Tailscale API key
- `vault_nfs_uid`: NFS user ID (default: 3000)
- `vault_nfs_gid`: NFS group ID (default: 3000)
- `vault_services_admin_username`: AdGuard Home admin username
- `vault_services_admin_password`: AdGuard Home admin password
- `nfs_server`: NAS hostname
- `nfs_data_path`: NFS export path

## Important Notes

### Tailscale Hostnames

After Phase 2, all VMs are accessible via Tailscale hostnames:

- `home-assistant.discus-moth.ts.net`
- `nas.discus-moth.ts.net`
- `jellyfin.discus-moth.ts.net`
- `media-services.discus-moth.ts.net`
- `download-clients.discus-moth.ts.net`
- `satisfactory-server.discus-moth.ts.net`

### Network Transition

**Before Phase 2**: SSH via IP addresses (`192.168.0.x`)
**After Phase 2**: SSH via Tailscale hostnames (preferred)

Both methods work after Phase 2, but Tailscale is recommended.

### NFS Client Mounting

NFS clients (Media Services, Download Clients, Jellyfin) will mount the NFS share in Phase 3. The NFS server is ready
after Phase 2.

## Re-Running Phase 2

Phase 2 is idempotent:

```bash
# Safe to re-run
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml
```

**Note**: Re-running won't recreate Btrfs array if it exists, but will reconfigure NFS and Tailscale.

## Success Criteria

✅ Phase 2 is complete when:

- [ ] Btrfs RAID1 array created and mounted
- [ ] NFS server running with exports configured
- [ ] Tailscale installed on all VMs
- [ ] All VMs visible in `tailscale status`
- [ ] Can SSH to VMs via Tailscale hostnames
- [ ] NAS accessible via `nas.discus-moth.ts.net`
- [ ] AdGuard Home container running on NAS
- [ ] AdGuard Home Web UI accessible at http://nas.discus-moth.ts.net:80
- [ ] DNS queries to AdGuard Home return results (test with `dig`)

## Next Steps

After Phase 2 completes:

1. ✅ Verify Btrfs array and NFS exports
2. ✅ Confirm all VMs in Tailscale network
3. ➡️ Proceed to [Phase 3: Services](phase3-services.md)

## Reference

- [Phase-Based Deployment](phase-based-deployment.md) - All phases overview
- [Initial Setup Guide](initial-setup.md) - Complete setup walkthrough
- [AdGuard Home Configuration](../configuration/adguard-home.md) - Complete DNS setup guide
- [DNS Troubleshooting](../troubleshooting/dns.md) - DNS issues and solutions
- [NAS Setup Reference](../reference/nas-setup.md) - Btrfs details
- [Tailscale Configuration](../reference/tailscale-auto-approval.md) - Tailscale ACLs
- [Networking Guide](../configuration/networking.md) - Network architecture
