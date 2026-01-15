# Phase 1: Infrastructure Provisioning

Provision all virtual machines on Proxmox.

## Overview

Phase 1 creates the foundation of your homelab by provisioning all 6 VMs on Proxmox using cloud-init templates.

**Estimated Time**: 3-5 minutes

> **📦 Modern Approach**: This project is transitioning to **Packer golden images** for faster, more reliable VM
provisioning. Golden images include pre-installed software (Podman, monitoring agents, security baselines) reducing
deployment time from 10-15 minutes to 2-3 minutes per VM. See [`infrastructure/packer/`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/) for details.
>
> **Troubleshooting Packer builds**: If experiencing SSH timeout issues with Packer builds, see
> [docs/troubleshooting/packer.md](../troubleshooting/packer.md) for the troubleshooting guide.

## Prerequisites

- [Initial setup](initial-setup.md) completed (Phases 0-3)
- Proxmox host accessible via Tailscale
- Tailscale SSH enabled on Proxmox host
- Vault configured with Proxmox credentials
- SSH keys generated and copied to Proxmox

## What Phase 1 Does

### 1. Creates Cloud-Init Template (VMID 9000)

- Downloads Ubuntu 24.04 cloud image
- Creates template VM with cloud-init support
- Configures VirtIO drivers and serial console
- Injects SSH key for ansible user

### 2. Clones 6 VMs from Template

- **Home Assistant** (VMID 100): 2 cores, 4GB RAM, 40GB disk
- **Satisfactory** (VMID 200): 2 cores (pinned), 6GB RAM, 60GB disk
- **NAS** (VMID 300): 2 cores, 6GB RAM, 3x 6TB passthrough disks
- **Jellyfin** (VMID 400): 4 cores, 8GB RAM, 80GB disk
- **Media Services** (VMID 401): 2 cores, 6GB RAM, 50GB disk
- **Download Clients** (VMID 402): 2 cores, 6GB RAM, 60GB disk

### 3. Configures Each VM

- Network: Static IP, gateway, DNS
- SSH: Ansible public key injection
- User: Creates ansible user with sudo access
- Cloud-init: Hostname, timezone configuration

### 4. Starts All VMs

- Powers on all VMs
- Waits for cloud-init completion
- Verifies SSH connectivity

## Running Phase 1

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
```

## Expected Output

```text
PLAY [Provision VMs] ***************************************************

TASK [Download Ubuntu cloud image] *************************************
changed: [jellybuntu.discus-moth.ts.net]

TASK [Create cloud-init template] **************************************
changed: [jellybuntu.discus-moth.ts.net]

TASK [Clone VMs from template] *****************************************
changed: [jellybuntu.discus-moth.ts.net] => (item=home-assistant)
changed: [jellybuntu.discus-moth.ts.net] => (item=nas)
changed: [jellybuntu.discus-moth.ts.net] => (item=jellyfin)
...

TASK [Start VMs] *******************************************************
changed: [jellybuntu.discus-moth.ts.net]

PLAY RECAP *************************************************************
jellybuntu.discus-moth.ts.net : ok=15 changed=12
```

## Verification

### Check VMs Created

```bash
ssh root@jellybuntu.discus-moth.ts.net "qm list"
```

Expected output:

```text
VMID NAME                  STATUS    MEM(MB)  BOOTDISK(GB)
100  home-assistant        running   4096     40.00
200  satisfactory-server   running   6144     60.00
300  nas                   running   6144     500.00
400  jellyfin              running   8192     80.00
401  media-services        running   6144     50.00
402  download-clients      running   6144     60.00
9000 ubuntu-cloud-template stopped   2048     10.00
```

### Verify VMs Running

```bash
# Check multiple VMs
ssh root@jellybuntu.discus-moth.ts.net "qm status 100"  # Home Assistant
ssh root@jellybuntu.discus-moth.ts.net "qm status 400"  # Jellyfin
```

### Test SSH Connectivity

```bash
# Connect via IP addresses (Tailscale not yet configured on VMs)
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10  # Home Assistant
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.15  # NAS
```

### Verify Cloud-Init

```bash
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10 "cloud-init status"
```

Expected: `status: done`

## VM Specifications

| VM | VMID | IP | Cores | RAM | Disk | Purpose |
|----|------|-----|-------|-----|------|---------|
| Home Assistant | 100 | .10 | 2 | 4GB | 40GB | Home automation |
| Satisfactory | 200 | .11 | 2* | 6GB | 60GB | Game server |
| NAS | 300 | .15 | 2 | 6GB | 3x6TB | Btrfs RAID1 + NFS |
| Jellyfin | 400 | .12 | 4 | 8GB | 80GB | Media streaming |
| Media Services | 401 | .13 | 2 | 6GB | 50GB | Sonarr/Radarr |
| Download Clients | 402 | .14 | 2 | 6GB | 60GB | qBittorrent/SABnzbd |

*Satisfactory cores pinned to physical cores 2-3

## Troubleshooting

### Template Creation Fails

**Error**: `Failed to download cloud image`

**Solution**:

```bash
# Check connectivity
ssh root@jellybuntu.discus-moth.ts.net "ping -c 3 cloud-images.ubuntu.com"

# Manual download
ssh root@jellybuntu.discus-moth.ts.net
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### Insufficient Resources

**Error**: `Storage allocation failed`

**Solution**:

```bash
# Check resources
ssh root@jellybuntu.discus-moth.ts.net "pvesm status"
ssh root@jellybuntu.discus-moth.ts.net "free -h"

# Reduce allocations in playbooks/vars.yml if needed
```

### VM Won't Start

**Solution**:

```bash
# Check VM config
ssh root@jellybuntu.discus-moth.ts.net "qm config 100"

# Check logs
ssh root@jellybuntu.discus-moth.ts.net "journalctl -u pvedaemon -n 50"

# Manual start
ssh root@jellybuntu.discus-moth.ts.net "qm start 100"
```

### Cloud-Init Timeout

**Solution**:

```bash
# SSH and check status
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.10
cloud-init status --long
cat /var/log/cloud-init.log

# Common issues:
# - Network misconfiguration: check /etc/netplan/
# - DNS problems: check /etc/resolv.conf
# - Package errors: check /var/log/apt/
```

### Wrong Proxmox Node Name

**Error**: `Node 'jellybuntu' not found`

**Solution**:

```bash
# Check actual node name
ssh root@jellybuntu.discus-moth.ts.net "pvesh get /nodes"

# Update playbooks/vars.yml
proxmox_node: "your_actual_node_name"
```

## Playbook Details

**File**: [`playbooks/core/01-provision-vms.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/01-provision-vms.yml)

**Variables** (from [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml)):

- `proxmox_api_host`: Proxmox hostname
- `proxmox_node`: Proxmox node name
- `vms`: VM definitions with specifications

**Roles**: Uses `community.general.proxmox` collection

## Re-Running Phase 1

Phase 1 is idempotent:

```bash
# Safe - only creates missing VMs
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
```

To recreate a specific VM:

```bash
# Delete VM
ssh root@jellybuntu.discus-moth.ts.net "qm stop 100 && qm destroy 100"

# Re-run Phase 1
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
```

## Success Criteria

✅ Phase 1 is complete when:

- [ ] All 6 VMs created in Proxmox
- [ ] All VMs powered on
- [ ] Can SSH to VMs via IP address
- [ ] Cloud-init status shows "done"
- [ ] Ansible user has sudo access

## Next Steps

After Phase 1 completes:

1. ✅ Verify all VMs running
2. ➡️ Proceed to [Phase 2: Networking](phase2-networking.md)

## Reference

- [Phase-Based Deployment](phase-based-deployment.md) - All phases overview
- [Initial Setup Guide](initial-setup.md) - Complete setup walkthrough
- [Architecture Overview](../architecture.md) - Infrastructure design
- [VM Specifications](../reference/vm-specifications.md) - Detailed VM specs
