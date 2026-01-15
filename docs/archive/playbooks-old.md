# Playbooks Reference

Complete reference for all Ansible playbooks in the Jellybuntu infrastructure.

## Execution Order

Playbooks are numbered in logical deployment order:

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12
                            ↓
                      (Optional: run after GUI config)
```

## Playbook Descriptions

### 01-provision-vms.yml

**Purpose**: Provision all VMs on Proxmox

**What It Does**:

- Downloads Ubuntu cloud image ISO
- Creates cloud-init template (VMID 9000)
- Provisions all VMs with static IPs
- Configures CPU allocation, pinning, and flags
- Sets memory and disk allocations

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 01-provision-vms.yml
```

**Key Features**:

- Cloud-init for automated setup
- CPU pinning for high-priority VMs
- cpu_flags support (e.g., +aes for Jellyfin)
- Static IP assignment

---

### 02-configure-tailscale.yml

**Purpose**: Install and configure Tailscale on all Ubuntu VMs

**What It Does**:

- Installs Tailscale on each VM
- Generates ephemeral auth keys via Tailscale API
- Joins VMs to Tailscale network
- Configures hostnames

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 02-configure-tailscale.yml
```

**Requirements**:

- Tailscale API key in vault.yml
- VMs must be running and accessible

---

### 03-configure-home-assistant.yml

**Purpose**: Deploy Home Assistant in Docker

**What It Does**:

- Installs Docker
- Creates Home Assistant container
- Configures volume mounts and networking

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 03-configure-home-assistant.yml
```

**Post-Deployment**:

- Access: http://home-assistant.discus-moth.ts.net:8123
- Complete initial setup wizard

---

### 04-configure-satisfactory.yml

**Purpose**: Deploy Satisfactory dedicated server

**What It Does**:

- Installs SteamCMD
- Downloads Satisfactory server
- Creates systemd service
- Configures firewall rules

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 04-configure-satisfactory.yml
```

**Post-Deployment**:

- Server runs on dedicated cores (2-3)
- Access: satisfactory-server.discus-moth.ts.net:7777

---

### 05-configure-media-services.yml

**Purpose**: Deploy media management stack (Sonarr, Radarr, Prowlarr, Jellyseerr, Flaresolverr, Recyclarr)

**What It Does**:

- Installs Docker
- Copies modular compose files from repository
- Creates Trash Guides folder structure
- Deploys media services stack
- Starts all containers

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 05-configure-media-services.yml
```

**Services Deployed**:

- Sonarr (8989), Radarr (7878), Prowlarr (9696)
- Jellyseerr (5055), Flaresolverr (8191), Recyclarr

**Note**: Download clients (qBittorrent, SABnzbd) are on separate VM - see playbook 06

---

### 06-configure-download-clients.yml

**Purpose**: Deploy download clients on dedicated VM

**What It Does**:

- Installs Docker on download-clients VM
- Deploys qBittorrent and SABnzbd
- Applies SABnzbd configuration from template
- Verifies configuration (host_whitelist, local_ranges, directories)

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 06-configure-download-clients.yml
```

**Services Deployed**:

- qBittorrent: http://192.168.0.14:8080
- SABnzbd: http://192.168.0.14:8081

**Key Features**:

- Templated SABnzbd config (configs/sabnzbd.ini.j2)
- Configuration verification steps
- Isolated from media services for better resource management

---

### 07-configure-flaresolverr.yml

**Purpose**: Configure Flaresolverr for Cloudflare bypass

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 07-configure-flaresolverr.yml
```

**Note**: Usually deployed with playbook 05 as part of media stack

---

### 08-configure-recyclarr.yml

**Purpose**: Configure Recyclarr for custom formats and quality profiles

**What It Does**:

- Configures Recyclarr with API keys from vault
- Sets up custom formats from Trash Guides
- Syncs quality profiles to Sonarr/Radarr

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 08-configure-recyclarr.yml
```

**Requirements**:

- Sonarr/Radarr API keys in vault.yml
- Sonarr/Radarr must be configured first

---

### 09-configure-nfs-and-migrate-to-storage.yml

**Purpose**: Migrate media services from local to NFS storage

**What It Does**:

- Verifies TrueNAS NFS server is reachable
- Creates NFS user/group (UID/GID 3000)
- Creates Trash Guides folder structure on NFS
- Mounts NFS share at /mnt/data
- Restarts media services to use NFS

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 09-configure-nfs-and-migrate-to-storage.yml
```

**Prerequisites**:

1. TrueNAS installed and configured
2. NFS share created: /mnt/tank/data
3. nfsuser created on TrueNAS (UID/GID 3000)

**Note**: Run AFTER TrueNAS manual setup. See [reference/truenas-setup.md](truenas-setup.md)

---

### 10-configure-jellyfin.yml

**Purpose**: Deploy Jellyfin with NFS access and transcoding optimizations

**What It Does**:

- Installs Jellyfin (native package)
- Mounts NFS share from TrueNAS
- Configures system limits (memlock, nofile)
- Sets CPU governor to performance mode
- Configures systemd service for high priority (Nice=-10, realtime IO)

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 10-configure-jellyfin.yml
```

**Post-Deployment**:

- Access: http://jellyfin.discus-moth.ts.net:8096
- Add media libraries: /mnt/data/media/tv, /mnt/data/media/movies

**Optimizations**:

- 4 cores for parallel transcoding
- CPU governor: performance
- High scheduling priority
- AES CPU flags for better codec performance

---

### 11-configure-ufw-firewall.yml

**Purpose**: Configure UFW firewall with network segmentation

**What It Does**:

- Enables UFW firewall
- Restricts SSH to Tailscale network only
- Allows service access from local network + Tailscale
- Configures default deny policy

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 11-configure-ufw-firewall.yml
```

**⚠️ WARNING**: After running this, SSH is ONLY accessible via Tailscale!

**Network Rules**:

- SSH: Tailscale only (100.64.0.0/10)
- Services: Local (192.168.0.0/24) + Tailscale
- All other: Denied

---

### 12-configure-unattended-upgrades.yml

**Purpose**: Configure automatic security updates

**What It Does**:

- Installs unattended-upgrades package
- Configures automatic security updates
- Disables auto-reboot (manual reboots for kernel updates)
- Enables automatic package cleanup

**Usage**:
```bash
ansible-playbook -i ../inventory.ini 12-configure-unattended-upgrades.yml
```

**What Gets Updated**:

- Ubuntu security updates: Automatic
- Regular package updates: Manual only
- Kernel updates: Manual reboot required

---

## Orchestration Playbook

### main.yml

**Purpose**: Run all playbooks in correct order

**What It Does**:

- Imports playbooks 01-12 in sequence
- Full infrastructure deployment

**Usage**:
```bash
ansible-playbook -i ../inventory.ini main.yml
```

**Note**: Playbooks 09 and 10 may be skipped if TrueNAS is not yet configured

---

## Utility Playbooks

### power-management.yml

**Purpose**: Power on/off VMs in bulk

**Usage**:
```bash
# Shutdown non-essential VMs
ansible-playbook power-management.yml -e power_action=shutdown

# Start all VMs
ansible-playbook power-management.yml -e power_action=startup

# Setup cron jobs
ansible-playbook power-management.yml -e setup_cron=true
```

---

## Variables and Configuration

### vars.yml

**Location**: `playbooks/vars.yml`

**Contains**:

- VM definitions (VMID, cores, RAM, disk, IP)
- Network configuration
- Resource allocation
- CPU pinning ranges

**Example**:
```yaml
vms:
  jellyfin:
    vmid: 400
    cores: 4
    cpu_type: "host"
    cpu_flags: "+aes"
    memory: 8192
    disk_size: "80G"
    ip_address: "192.168.0.12"
```

### vault.yml

**Location**: Root directory (encrypted)

**Contains**:

- Proxmox API password
- Tailscale API key
- NFS UID/GID
- Service API keys (Sonarr, Radarr, etc.)

**Usage**:
```bash
# Edit vault
ansible-vault edit vault.yml

# View vault
ansible-vault view vault.yml
```

---

## See Also

- [Deployment Guides](../deployment/initial-setup.md)
- [Architecture Overview](../architecture.md)
- [Service Endpoints](../configuration/service-endpoints.md)
