# Initial Setup Guide

Complete walkthrough for deploying Jellybuntu from scratch to a fully functional homelab.

## Overview

This guide walks you through the complete setup process:

1. **Prerequisites** - System requirements and accounts
2. **Bootstrap** - Setup wizard and dependency installation
3. **Proxmox Configuration** - API user and authentication
4. **Credentials** - Tailscale keys and vault configuration
5. **Infrastructure Deployment** - Phase-based deployment (Phases 1-3)
6. **Manual Configuration** - Service configuration through web UIs
7. **Security Hardening** - Phase 4 deployment (Recyclarr, firewall, updates)
8. **Validation** - Testing and troubleshooting

**Estimated Time**: 45-60 minutes for complete setup

## Prerequisites

### Hardware Requirements

- **Proxmox VE** server with:
  - At least 8 CPU cores
  - 48GB RAM (minimum 32GB)
  - 500GB+ storage space
  - Network connectivity

### Software Requirements

- **Workstation** running Ubuntu/Debian, Arch Linux, or macOS
- **Git** installed
- **SSH access** to Proxmox host
- **Internet connection** for downloads
- **Required CLI tools** (setup script will auto-install if missing):
  - `curl` - HTTP requests (required for downloading dependencies)
  - `jq` - JSON parsing (required for Tailscale API and other scripts)
  - `sops` and `age` - secrets encryption
  - Arch: `paru -S curl jq sops age`
  - macOS: `brew install curl jq sops age`
  - Ubuntu: `sudo apt install curl jq` (sops/age installed by setup script)

### Proxmox Host Requirements

- **Tailscale** installed and running on Proxmox host
  - Installation: `curl -fsSL https://tailscale.com/install.sh | sh`
  - Start: `tailscale up`
  - Verify: `tailscale status`
- **Tailscale SSH** enabled (recommended)
  - Allows SSH via Tailscale hostnames
  - Configuration: Enable in Tailscale admin console or use `tailscale up --ssh`
- **Root or sudo access** for initial setup

### Proxmox Configuration Prerequisites

The following Proxmox configuration must be in place before running the setup:

**Storage Pools** (verify with `pvesm status` on Proxmox host):

| Pool | Purpose | Required |
|------|---------|----------|
| `local-zfs` | VM disk storage (preferred) | Yes (or `local-lvm`) |
| `local-lvm` | Alternative VM disk storage | Yes (if no `local-zfs`) |
| `local` | ISO/template storage | Yes |

If your storage pools have different names, update [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml):

```yaml
storage_pool: "your-pool-name"      # Default: local-zfs
iso_storage: "your-iso-storage"     # Default: local
```

**Network Bridge**:

- Bridge `vmbr0` must exist and be connected to your LAN
- VMs will use static IPs across VLAN subnets (192.168.10.0/24, 192.168.20.0/24, 192.168.30.0/24, 192.168.40.0/24)
- Verify with: `ip addr show vmbr0`

If using a different bridge or IP range, update [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml):

```yaml
vm_network_bridge: "vmbr0"          # Your bridge name
vm_network_subnet: "192.168.10.0/24" # Your management VLAN subnet
vm_network_gateway: "192.168.10.1"   # Your management VLAN gateway
```

**VM ID Range**:

- VMIDs 100-500 should be available (not in use by existing VMs)
- Verify with: `qm list`
- If conflicts exist, update VMIDs in [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml)

**Proxmox Version**:

- Proxmox VE 7.0 or later required
- Verify with: `pveversion`

### External Services

- **Tailscale Account** (free tier works)
  - Sign up at https://tailscale.com
  - Access to admin console for API key generation

### Knowledge Prerequisites

- Basic Linux command line
- Understanding of SSH keys
- Familiarity with Ansible concepts
- Basic networking knowledge

## Phase 0: Bootstrap (10 minutes)

### Step 1: Clone Repository

```bash
# Clone the repository
git clone <repository-url> jellybuntu
cd jellybuntu

# Verify structure
ls -la
```

You should see:

- [`bin/bootstrap/setup.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/bin/bootstrap/setup.sh) - Main setup orchestrator
- `playbooks/` - Ansible playbooks
- `roles/` - Reusable Ansible roles
- `docs/` - Documentation

### Step 2: Run Setup Wizard

```bash
./bin/bootstrap/setup.sh
```

The setup wizard performs 8 automated steps:

#### Step 0: Verify Prerequisites

- Checks that you're running from the repository root
- Verifies Python3, pip, curl, git, and SSH client are installed
- Tests network connectivity to GitHub
- Validates that required config files exist (playbooks/vars.yml, inventory.ini)

#### Step 1: Install Dependencies

- Installs Ansible (via pip or apt)
- Installs Python packages (proxmoxer, requests)
- Installs community Ansible collections (community.sops, containers.podman, etc.)

#### Step 2: Configure Ansible

- Creates required directories
- Generates ansible.cfg
- Sets up inventory structure

#### Step 3: Configure SSH Access

- Creates `~/.ssh/ansible_homelab` key pair
- Copies public key to Proxmox host
- Enables passwordless SSH for automation

#### Step 3b: Verify Tailscale on Proxmox

- Connects to Proxmox host via SSH
- Verifies Tailscale is installed and running
- Provides installation instructions if missing
- Can be skipped with user confirmation

#### Step 4: Create Admin User (Optional)

- Creates dedicated Proxmox administrator user
- Recommended over using root for daily operations
- Can be skipped with `--skip-admin`

#### Step 5: Initialize SOPS Secrets

- Creates `.sops.yaml` configuration if missing
- Creates [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml) with SOPS encryption
- **Prompts for media services admin credentials**:
  - Username (default: admin)
  - Password (with confirmation)
  - Used for: qBittorrent, SABnzbd, Sonarr, Radarr, Prowlarr, Jellyseerr
- Generates age key pair for automatic encryption/decryption
- No password prompts needed during playbook execution

**Important**: The media services credentials you set here will be used across all services for consistent authentication.

#### Step 6: Generate Configs

- Creates [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml) from template
- Sets up default configuration
- Can be customized later

#### Step 7: Create Helper Scripts

- Generates `verify-setup.sh` for post-deployment verification
- Creates `power-management.yml` for VM power control

#### Setup Options

```bash
# Skip dependency installation (if already installed)
./bin/bootstrap/setup.sh --skip-deps

# Skip admin user creation (use root@pam)
./bin/bootstrap/setup.sh --skip-admin

# Non-interactive mode with defaults
./bin/bootstrap/setup.sh --non-interactive

# Show help
./bin/bootstrap/setup.sh --help
```

#### Re-running Individual Steps

Each step can be re-run independently:

```bash
# Re-verify prerequisites
./bin/bootstrap/lib/00-verify-prerequisites.sh

# Re-install dependencies
./bin/bootstrap/lib/01-install-dependencies.sh

# Re-configure Ansible
./bin/bootstrap/lib/02-configure-ansible.sh

# Re-generate SSH keys
./bin/bootstrap/lib/03-generate-ssh-keys.sh

# Re-copy SSH key to Proxmox
./bin/bootstrap/lib/03b-copy-ssh-key-to-proxmox.sh

# Re-verify Tailscale on Proxmox
./bin/bootstrap/lib/03c-verify-tailscale-on-proxmox.sh

# Re-create admin user
./bin/bootstrap/lib/04-create-admin-user.sh

# Re-initialize SOPS secrets (will prompt for credentials again)
./bin/bootstrap/lib/05-initialize-sops.sh

# Re-generate configs
./bin/bootstrap/lib/06-generate-configs.sh

# Re-create helper scripts
./bin/bootstrap/lib/07-create-helper-scripts.sh
```

### Step 3: Verify Bootstrap

```bash
# Check Ansible installation
ansible --version

# Verify SSH key was created
ls -la ~/.ssh/ansible_homelab*

# Confirm SOPS secrets file exists
ls -la group_vars/all.sops.yaml

# Test Proxmox SSH connection
ssh root@jellybuntu.discus-moth.ts.net
```

## Phase 1: Proxmox Configuration (5 minutes)

### Step 1: Create Proxmox API User

Create a dedicated user for Ansible automation (principle of least privilege):

```bash
./bin/bootstrap/create-proxmox-api-user.sh
```

This script:

1. Connects to Proxmox via SSH
2. Creates `ansible@pve` user with custom `Ansible` role
3. Assigns required permissions for both Ansible and OpenTofu/Terraform
4. Prompts for a secure password (validates complexity)
5. Configures the user for API access

**Required Permissions** (Full list):

- **VM Operations**: Allocate, Clone, Configure (CPU/Memory/Disk/Network/Hardware/Cloudinit)
- **VM Management**: Power, Console, Audit, Migration, Backup, Snapshot, Replication
- **Guest Agent**: Full access for monitoring and file operations (OpenTofu)
- **Storage**: Allocate space, Templates, Audit
- **Pools**: Create/allocate pools, Audit
- **System**: Audit, Modify (for boot order), SDN usage

**Note**: These permissions support both Ansible playbooks and OpenTofu/Terraform infrastructure-as-code operations.

See [reference/proxmox-api-permissions.md](../reference/proxmox-api-permissions.md) for complete permission breakdown
and rationale.

### Step 2: Verify API User

Test the API user connection:

```bash
# This will fail until vault is configured, but verifies user exists
ansible proxmox_hosts -m ping
```

## Phase 2: Credentials Configuration (10 minutes)

### Step 1: Generate Tailscale API Key

1. Visit https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Configure key settings:
   - **Reusable**: Yes (will be used for multiple VMs)
   - **Ephemeral**: Yes (VMs are disposable)
   - **Expiration**: 90 days or longer
   - **Tags**: Optional, can add for ACL automation
4. Copy the generated key (starts with `tskey-api-`)

**Note**: The key will only be displayed once. Save it securely.

### Step 2: Configure Secrets

Edit the encrypted secrets file:

```bash
sops group_vars/all.sops.yaml
```

The secrets file was pre-populated by `setup.sh`. Update the following variables:

```yaml
# Proxmox Authentication (UPDATE THIS)
vault_proxmox_password: "password_from_create_script"

# Tailscale Configuration (ADD THIS)
vault_tailscale_api_key: "tskey-api-xxxxxxxxxxxxxxxxxxxxx"

# NFS User/Group IDs (default: 3000, can be changed)
vault_nfs_uid: 3000
vault_nfs_gid: 3000

# Media Services Admin Credentials (ALREADY SET by setup.sh)
# These are used for qBittorrent, SABnzbd, Sonarr, Radarr, Prowlarr, Jellyseerr
vault_services_admin_username: "admin"
vault_services_admin_password: "your_password_from_setup"

# SMM (Satisfactory Mod Manager) Authentication
# Password for ansible user on Satisfactory server (for SMM SFTP access)
vault_smm_ansible_password: "your_secure_password_here"

# Service API Keys (ADD AFTER Phase 3 deployment)
# vault_sonarr_api_key: ""
# vault_radarr_api_key: ""
```

**Important**:

- Update `vault_proxmox_password` with the password from `create-proxmox-api-user.sh`
- Add your Tailscale API key
- Media services credentials are already set from setup.sh
- Service API keys will be added later (after Phase 3)

Save and exit (`:wq` in vim).

### Step 3: Verify Secrets

```bash
# View secrets (decrypted)
sops -d group_vars/all.sops.yaml

# Test Proxmox connection
ansible proxmox_hosts -m ping
```

## Phase 3: Configuration Review (5 minutes)

### Step 1: Review VM Configuration

Edit [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml) to verify VM specifications:

```yaml
# Proxmox configuration
proxmox_api_host: "jellybuntu.discus-moth.ts.net"
proxmox_node: "jellybuntu"

# VM Definitions
vms:
  home-assistant:
    vmid: 100
    cores: 2
    memory: 4096
    disk_size: "40G"
    # ... more settings

  nas:
    vmid: 300
    cores: 2
    memory: 6144
    additional_disks:
      - size: 500G
      - size: 500G
```

**Adjust as needed**:

- CPU cores (14 vCPU on 8 physical cores by default)
- Memory allocation (34GB total by default)
- Disk sizes
- Network settings
- Proxmox hostname/node (must match your installation)

See [configuration/resource-allocation.md](../configuration/resource-allocation.md) for guidance.

### Step 2: Review Network Configuration

Check [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml) for network settings:

```yaml
# Network configuration
vm_network_gateway: "192.168.10.1"
vm_network_dns:
  - "9.9.9.9"
  - "192.168.10.1"
```

**Update if needed**:

- Gateway address
- DNS servers
- Subnet (default: 192.168.10.0/24 management VLAN)

### Step 3: Review Inventory

Check [`inventory.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory.ini) for host definitions:

```ini
[proxmox_hosts]
jellybuntu.discus-moth.ts.net

[home_assistant]
home-assistant ansible_host=home-assistant.discus-moth.ts.net

[nas_servers]
nas ansible_host=nas.discus-moth.ts.net

# ... more VMs
```

The inventory is pre-configured for Tailscale hostnames. VMs will be accessible after deployment.

## Phase 4: Infrastructure Deployment (20 minutes)

Now deploy the infrastructure using the automated playbooks. This phase runs **Deployment Phases 1-3** of the playbooks.

### Deployment Strategy

You have two options:

**Option A: All-at-once deployment** (fastest, 15-20 minutes)

```bash
./bin/runtime/ansible-run.sh playbooks/main.yml
```

**Option B: Phase-based deployment** (recommended for first-time, 20-25 minutes)

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase2-bootstrap.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

**We recommend Option B** for initial setup as it provides:

- Better visibility into each deployment stage
- Easier troubleshooting if issues occur
- Ability to verify each phase before proceeding

See [phase-based-deployment.md](phase-based-deployment.md) for detailed phase information.

### Deployment Phase 1: Infrastructure Provisioning (3-5 minutes)

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
```

**What happens**:

- Cloud-init template created (VMID 9000)
- All VMs cloned from template
- VMs configured with:
  - SSH keys
  - Network settings
  - Resource allocations
  - Additional disks (NAS)
- VMs started automatically

**Playbooks executed**:

- [`playbooks/infrastructure/provision-vms.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/infrastructure/provision-vms.yml) - Creates all 8 VMs

**Verification**:

```bash
# Check VMs were created
ssh root@jellybuntu.discus-moth.ts.net "qm list"

# Verify VMs are running
ssh root@jellybuntu.discus-moth.ts.net "qm status 100"  # Home Assistant
ssh root@jellybuntu.discus-moth.ts.net "qm status 300"  # NAS
ssh root@jellybuntu.discus-moth.ts.net "qm status 400"  # Jellyfin
```

### Deployment Phase 2: Bootstrap Configuration (4-6 minutes)

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase2-bootstrap.yml
```

**What happens**:

- NAS VM configured:
  - Btrfs RAID1 array created
  - NFS server installed
  - Storage directories created
  - NFS exports configured
- Tailscale installed on all VMs:
  - Ephemeral keys generated via API
  - VMs join Tailscale network
  - Hostnames registered

**Playbooks executed**:

- [`playbooks/infrastructure/nas.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/infrastructure/nas.yml) - Btrfs + NFS setup
- [`playbooks/networking/tailscale.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/networking/tailscale.yml) - VPN mesh network

**Verification**:

```bash
# Check Tailscale status
tailscale status

# Verify NFS exports
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net "sudo exportfs -v"

# Test NAS connectivity
ping nas.discus-moth.ts.net
```

**Important**: After Phase 2, all VMs are accessible via Tailscale hostnames (`.discus-moth.ts.net`).

### Deployment Phase 3: Services Deployment (8-12 minutes)

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

**What happens**:

- Home Assistant deployed (Docker)
- Satisfactory game server deployed (SteamCMD)
- Media services deployed (Docker):
  - Sonarr, Radarr, Prowlarr
  - Jellyseerr, Byparr
- Download clients deployed (Docker):
  - **qBittorrent** - Automatically configured via Web API:
    - Sets download paths and preferences
    - Creates categories (tv, movies)
    - **Sets permanent password from vault** (`services_admin_password`)
  - **SABnzbd** - Configuration patched after container starts
- NFS storage mounted on all client VMs
- Jellyfin installed (native package with optimizations)

**Playbooks executed**:

- [`playbooks/services/home-assistant.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/home-assistant.yml)
- [`playbooks/services/satisfactory.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/satisfactory.yml)
- [`playbooks/services/media-services.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/media-services.yml)
- [`playbooks/services/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/download-clients.yml) - **Includes qBittorrent API configuration**
- [`playbooks/networking/nfs-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/networking/nfs-clients.yml)
- [`playbooks/services/jellyfin.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/jellyfin.yml)

**NOT included in Phase 3** (will run in Deployment Phase 4 after manual configuration):

- Recyclarr (requires API keys)
- UFW firewall (security hardening)
- Unattended upgrades

**qBittorrent Auto-Configuration Details**:
During Phase 3, qBittorrent is automatically configured via Web API:

1. Container starts with temporary password
2. Ansible extracts temp password from logs
3. Authenticates via Web API
4. **Download paths**: `/data/torrents`, `/data/torrents/incomplete`, `/data/torrents/.torrents` export
5. **Categories**: `tv` → `/data/torrents/tv`, `movies` → `/data/torrents/movies`
6. **Performance limits**: 5 active downloads, 3 uploads, 10 total torrents
7. **Connection limits**: 500 global, 100 per torrent
8. **Privacy settings**: Anonymous mode, prefer encryption, DHT/PEX/LSD disabled
9. **Torrent management**: Automatic mode enabled for all categories
10. **Sets permanent password** to `vault_services_admin_password`
11. No manual qBittorrent configuration needed!

**Verification**:

```bash
# Check Docker containers on media services
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net "docker ps"

# Check Docker containers on download clients
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net "docker ps"

# Verify Jellyfin service
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net "systemctl status jellyfin"

# Check NFS mounts
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net "df -h | grep nfs"

# Verify qBittorrent login (should work with vault credentials)
# Access: http://download-clients.discus-moth.ts.net:8080
# Username: admin (or your vault_services_admin_username)
# Password: (your vault_services_admin_password)
```

### Infrastructure Deployment Complete

At this point:

- ✅ All VMs provisioned and running
- ✅ NAS configured with Btrfs RAID1 + NFS
- ✅ Tailscale VPN mesh established
- ✅ All services deployed and running
- ✅ **qBittorrent fully configured via API**
- ⏳ Manual configuration needed (API keys, download clients)
- ⏳ Security hardening pending (Deployment Phase 4)

## Phase 5: Manual Service Configuration (15 minutes)

Services are running but require manual configuration through web UIs before Deployment Phase 4 can run.

### Step 1: Retrieve API Keys

**Sonarr API Key**:

1. Access Sonarr: http://media-services.discus-moth.ts.net:8989
2. Navigate to **Settings** → **General** (show advanced settings)
3. Scroll to **Security** section
4. Copy the **API Key**

**Radarr API Key**:

1. Access Radarr: http://media-services.discus-moth.ts.net:7878
2. Navigate to **Settings** → **General** (show advanced settings)
3. Scroll to **Security** section
4. Copy the **API Key**

### Step 2: Add API Keys to Secrets

```bash
sops group_vars/all.sops.yaml
```

Add these lines:

```yaml
# Media Services API Keys (retrieved from Step 1)
vault_sonarr_api_key: "your_sonarr_api_key_here"
vault_radarr_api_key: "your_radarr_api_key_here"
```

Save and exit (`:wq`).

### Step 3: Configure Download Clients

**Login credentials for all services**:

- Username: `admin` (or your `vault_services_admin_username`)
- Password: (your `vault_services_admin_password` from setup.sh)

**In Prowlarr** (http://media-services.discus-moth.ts.net:9696):

1. Navigate to **Settings** → **Download Clients**
2. Add download clients:

   **qBittorrent** (already configured, just add connection):

   - Host: `download-clients.discus-moth.ts.net`
   - Port: `8080`
   - Username: `admin` (your vault username)
   - Password: (your vault password)

   **SABnzbd**:

   - Host: `download-clients.discus-moth.ts.net`
   - Port: `8081`
   - API Key: (get from SABnzbd: Config → General → API Key)
   - Username: `admin` (your vault username)
   - Password: (your vault password)

3. Navigate to **Settings** → **Apps** and add:
   - **Sonarr** (Full Sync)
     - Prowlarr Server: `http://prowlarr:9696`
     - Sonarr Server: `http://sonarr:8989`
     - API Key: (from Step 1)
   - **Radarr** (Full Sync)
     - Prowlarr Server: `http://prowlarr:9696`
     - Radarr Server: `http://radarr:7878`
     - API Key: (from Step 1)

**In Sonarr** (http://media-services.discus-moth.ts.net:8989):

1. Navigate to **Settings** → **Download Clients**
2. Add the same download clients as Prowlarr

**In Radarr** (http://media-services.discus-moth.ts.net:7878):

1. Navigate to **Settings** → **Download Clients**
2. Add the same download clients as Prowlarr

### Step 4: Verify Connectivity

Test that all connections work:

- In Sonarr/Radarr: **Settings** → **Download Clients** → **Test** (should show green checkmarks)
- In Prowlarr: **Indexers** → **Test All** (verify indexers respond)

See [post-deployment.md](post-deployment.md) for detailed configuration steps.

## Phase 6: Security Hardening (5 minutes)

Now that API keys are configured, run **Deployment Phase 4 playbook** for final security hardening.

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

**What happens**:

- **Recyclarr** configured with TRaSH Guides:
  - Uses Sonarr/Radarr API keys from vault
  - Applies custom formats
  - Configures quality profiles
- **UFW firewall** enabled:
  - SSH from Tailscale + local network (LAN fallback)
  - Services accessible from local network + Tailscale
  - External access blocked for security
- **Unattended upgrades** configured:
  - Automatic security updates
  - System stays patched

**Playbooks executed**:

- [`playbooks/services/recyclarr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/recyclarr.yml)
- [`playbooks/system/system-hardening.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/system/system-hardening.yml)
- [`playbooks/system/system-hardening.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/system/system-hardening.yml)

**Access Note**:
After Deployment Phase 4, SSH is accessible via both Tailscale and local network:

```bash
# Via Tailscale (preferred):
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Via local network (fallback for Tailscale outages):
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.13
```

**Verification**:

```bash
# Check firewall status
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net "sudo ufw status"

# Verify unattended upgrades
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl status unattended-upgrades"
```

### Complete Deployment Finished

All phases complete:

- ✅ Deployment Phase 1: VMs provisioned
- ✅ Deployment Phase 2: Bootstrap configured
- ✅ Deployment Phase 3: Services deployed (including qBittorrent auto-config)
- ✅ Manual configuration completed
- ✅ Deployment Phase 4: Security hardened

## Phase 7: Validation and Testing (10 minutes)

### Service Accessibility

Verify all services are accessible via Tailscale:

**Media Management**:

- Sonarr: http://media-services.discus-moth.ts.net:8989
- Radarr: http://media-services.discus-moth.ts.net:7878
- Prowlarr: http://media-services.discus-moth.ts.net:9696
- Jellyseerr: http://media-services.discus-moth.ts.net:5055

**Download Clients**:

- qBittorrent: http://download-clients.discus-moth.ts.net:8080
- SABnzbd: http://download-clients.discus-moth.ts.net:8081

**Media Server**:

- Jellyfin: http://jellyfin.discus-moth.ts.net:8096

**Home Automation**:

- Home Assistant: http://home-assistant.discus-moth.ts.net:8123

**Login for all services**:

- Username: `admin` (or your `vault_services_admin_username`)
- Password: (your `vault_services_admin_password` from setup.sh)

See [configuration/service-endpoints.md](../configuration/service-endpoints.md) for complete list.

### Connectivity Tests

```bash
# Test all VMs respond
ansible all -m ping

# Check Docker containers
ansible media_services -a "docker ps"

# Verify NFS mounts
ansible vms -a "df -h" | grep nfs

# Check firewall status
ansible vms -a "sudo ufw status"

# Verify Tailscale connectivity
ansible vms -a "tailscale status"
```

### Service Health Checks

Check Docker container status:

```bash
# Media services
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "cd /opt/media-stack && docker compose ps"

# Download clients
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "cd /opt/download-clients && docker compose ps"
```

All containers should show "Up" status.

### End-to-End Test

Test the complete automation workflow:

1. **Request Content**: Add a test show/movie in Jellyseerr
2. **Verify Queue**: Check that it appears in Sonarr/Radarr
3. **Monitor Download**: Watch qBittorrent/SABnzbd for activity
4. **Check Import**: Verify file appears in `/mnt/data/media/`
5. **Confirm Library**: Refresh Jellyfin library and verify item appears

## Troubleshooting

### Bootstrap Issues

**Problem**: Ansible installation fails

```bash
# Try alternative installation method
pip3 install ansible --user

# Or use apt (Ubuntu/Debian)
sudo apt update && sudo apt install ansible
```

**Problem**: SSH key already exists

```bash
# Backup existing key
mv ~/.ssh/ansible_homelab ~/.ssh/ansible_homelab.bak

# Re-run SSH key generation
./bin/bootstrap/lib/03-generate-ssh-keys.sh
```

**Problem**: Forgot media services password

```bash
# Re-run SOPS initialization (will prompt for new credentials)
./bin/bootstrap/lib/05-initialize-sops.sh
```

### Deployment Issues

**Problem**: Can't connect to Proxmox

```bash
# Verify SSH access
ssh root@jellybuntu.discus-moth.ts.net

# Check Proxmox credentials in secrets
sops -d group_vars/all.sops.yaml

# Test connection
ansible proxmox_hosts -m ping
```

**Problem**: VM provisioning fails

- Check available resources on Proxmox
- Verify storage space
- Review [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml) resource allocations
- Check Proxmox logs: `/var/log/pve/tasks/`

**Problem**: Tailscale installation fails

- Verify API key is correct
- Check key hasn't expired
- Ensure "Reusable" and "Ephemeral" are enabled
- Review Tailscale admin console for errors

**Problem**: Services not accessible

- Verify VMs are running: `ssh root@jellybuntu.discus-moth.ts.net "qm list"`
- Check Tailscale connectivity: `tailscale status`
- Verify Docker containers: `docker ps`

**Problem**: Deployment Phase 4 fails (Recyclarr)

- Ensure API keys are correct in vault
- Verify Sonarr/Radarr are accessible
- Check Recyclarr logs on media-services VM

**Problem**: qBittorrent password not working

- Password was set automatically during Phase 3 to `vault_services_admin_password`
- Verify secrets contain correct password: `sops -d group_vars/all.sops.yaml`
- Check qBittorrent logs: `docker logs qbittorrent`
- If needed, reset by removing qBittorrent config and rerunning playbook

### Service Issues

**Problem**: Docker containers not starting

```bash
# Check container logs
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker logs sonarr"

# Restart containers
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "cd /opt/media-stack && docker compose restart"
```

**Problem**: NFS mounts failing

```bash
# Check NFS server
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo systemctl status nfs-server"

# Verify exports
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo exportfs -v"

# Remount on client
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo mount -a"
```

**Problem**: Can't SSH after Deployment Phase 4

- Use Tailscale hostnames, not IP addresses
- Verify Tailscale is running on your workstation: `tailscale status`
- Check firewall is configured correctly: `sudo ufw status`

See [troubleshooting guides](../troubleshooting/common-issues.md) for service-specific issues.

## Next Steps

After completing initial setup:

1. **Configure Jellyseerr**: Link to Jellyfin and media services
2. **Add Media Libraries**: Configure Jellyfin library paths
3. **Customize Settings**: Adjust quality profiles, notifications
4. **Learn Maintenance**: Review [maintenance guides](../maintenance/updates.md)

## Reference

### Key Files

- [`bin/bootstrap/setup.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/bin/bootstrap/setup.sh) - Bootstrap orchestrator
- [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml) - Encrypted credentials (SOPS)
- [`inventory.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory.ini) - Host definitions
- [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml) - VM specifications and Proxmox config
- [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml) - Global variables

### Key Directories

- `playbooks/` - Ansible playbooks (core/, phases/, utility/)
- `roles/` - Reusable Ansible roles
- [`services/compose/`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/) - Docker Compose configurations
- [`services/configs/`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/) - Service configuration templates
- `bin/` - Bootstrap and runtime scripts

### Phase Playbooks

- [`playbooks/phases/phase1-infrastructure.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/phases/phase1-infrastructure.yml) - Provision VMs
- [`playbooks/phases/phase2-bootstrap.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/phases/phase2-bootstrap.yml) - Configure NAS + Tailscale
- [`playbooks/phases/phase3-services.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/phases/phase3-services.yml) - Deploy all services + qBittorrent auto-config
- [`playbooks/phases/phase4-post-deployment.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/phases/phase4-post-deployment.yml) - Security hardening (after manual config)

### Documentation

- [Architecture Overview](../architecture.md)
- [Quickstart Guide](../quickstart.md)
- [Phase-Based Deployment](phase-based-deployment.md)
- [Post-Deployment Configuration](post-deployment.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Troubleshooting](../troubleshooting/common-issues.md)

## Summary

You have now:

- ✅ Bootstrapped the development environment
- ✅ Set media services admin credentials (used across all services)
- ✅ Configured Proxmox authentication
- ✅ Set up encrypted credentials storage
- ✅ Deployed complete infrastructure (8 VMs)
- ✅ Configured networking (NAS + Tailscale)
- ✅ Deployed all services with automated qBittorrent configuration
- ✅ Completed manual service configuration
- ✅ Applied security hardening
- ✅ Verified system functionality

Your homelab is fully deployed and secured!
