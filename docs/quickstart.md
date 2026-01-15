# Quickstart Guide

Get your Jellybuntu homelab up and running in under 30 minutes.

## Prerequisites

### Proxmox Host Requirements

- **Proxmox VE** installed and accessible via SSH
- **Tailscale** installed and running on Proxmox host:

  ```bash
  # On Proxmox host:
  curl -fsSL https://tailscale.com/install.sh | sh
  tailscale up
  ```

### Workstation Requirements

- Ubuntu/Debian/Arch Linux or macOS with internet access
- Required CLI tools (setup script will auto-install if missing):
  - `curl` and `jq` - HTTP requests and JSON parsing
  - `sops` and `age` - secrets encryption
  - Arch: `paru -S curl jq sops age`
  - macOS: `brew install curl jq sops age`
  - Ubuntu: `sudo apt install curl jq` (sops/age installed by setup script)

### External Services

- **Tailscale account** (free tier works)
- Basic knowledge of Ansible and SSH

### Tailscale Network Name Customization

This project uses `discus-moth` as the example Tailscale network name (tailnet). You'll see hostnames like
`media-services.discus-moth.ts.net` throughout the documentation, inventory, and scripts.

**If you have a different Tailscale network name**, you must search and replace all occurrences:

```bash
# Find all files containing the example network name
grep -r "discus-moth" --include="*.yml" --include="*.yaml" --include="*.ini" --include="*.md" .

# Key files to update:
# - inventory.ini (all host definitions)
# - docs/*.md (service URLs in documentation)
# - verify-setup.sh (generated helper script - regenerate after updating)
```

Replace `discus-moth` with your actual tailnet name (visible at https://login.tailscale.com/admin/machines).

## Quick Setup (6 Steps)

### 1. Bootstrap (5 min)

```bash
# Clone repository (private - ensure you have access)
git clone <repository-url> jellybuntu
cd jellybuntu

# Run interactive setup wizard
./bin/bootstrap/setup.sh
```

The setup wizard will guide you through 8 steps:

0. Verify prerequisites (Python, pip, curl, network connectivity)
1. Install dependencies (Ansible, Python packages, collections)
2. Configure Ansible
3. Configure SSH access (generate keys, copy to Proxmox)
3b. Verify Tailscale on Proxmox (required for VPN mesh)
4. Create Proxmox admin user (optional, recommended)
5. Initialize SOPS secrets
6. Generate configuration files
7. Create helper scripts (verify-setup.sh, power-management.yml)

**Options**:

- `--skip-deps` - Skip dependency installation
- `--skip-admin` - Skip admin user creation
- `--non-interactive` - Use defaults

**Note**: During setup, you'll be prompted to create a dedicated administrator user for Proxmox. This is recommended
instead of using root for daily operations.

**Individual Steps**: Each step can be re-run independently:

```bash
./bin/bootstrap/lib/04-create-admin-user.sh    # Example: Re-create admin user
./bin/bootstrap/lib/07-create-helper-scripts.sh # Example: Regenerate helpers
```

### 2. Create Proxmox API User (3 min)

```bash
# Create dedicated Proxmox API user for Ansible
./bin/bootstrap/create-proxmox-api-user.sh
```

This creates `ansible@pve` user with limited permissions for automation (follows principle of least privilege).

### 3. Configure Credentials (5 min)

```bash
# Generate Tailscale API key
# Visit: https://login.tailscale.com/admin/settings/keys
# Create key with "Reusable" and "Ephemeral" enabled

# Edit secrets with credentials
sops group_vars/all.sops.yaml
```

Update the secrets file with:

```yaml
vault_proxmox_password: "your_ansible_pve_password"  # Password from step 2
vault_tailscale_api_key: "tskey-api-xxxxx"
vault_nfs_uid: 3000
vault_nfs_gid: 3000
```

### 4. Update Configuration (2 min)

Edit [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml):

- Verify VM resource allocation fits your hardware
- Update network settings if needed (default: 192.168.0.0/24)

### 5. Deploy Infrastructure (15 min)

**Option A: Deploy All at Once (fastest)** <!-- markdownlint-disable-line MD036 -->

```bash
./bin/runtime/ansible-run.sh playbooks/main.yml
```

**Option B: Deploy by Phase (recommended for first-time setup)** <!-- markdownlint-disable-line MD036 -->

```bash
# Phase 1: Provision VMs (3 min)
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml

# Phase 2: Configure NAS + Tailscale (4 min)
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml

# Phase 3: Deploy Services (8 min)
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

This deployment will:

- ✓ Provision all VMs on Proxmox (Home Assistant, Satisfactory, NAS, Jellyfin, Media Services, Download Clients,
  Monitoring, Automation)
- ✓ Configure Btrfs RAID1 NAS with NFS exports
- ✓ Install Tailscale VPN on all VMs
- ✓ Deploy all services (Home Assistant, Satisfactory, Sonarr/Radarr/Prowlarr, qBittorrent/SABnzbd, Jellyfin)
- ✓ Configure firewall (SSH via Tailscale + LAN)
- ✓ Enable automatic security updates
- ✓ (Optional) Deploy monitoring stack (Prometheus, Grafana, Uptime Kuma)
- ✓ (Optional) Deploy CI/CD infrastructure (Woodpecker CI)

### 6. Access Services (2 min)

Via Tailscale:

- **Sonarr**: http://media-services.discus-moth.ts.net:8989
- **Radarr**: http://media-services.discus-moth.ts.net:7878
- **Prowlarr**: http://media-services.discus-moth.ts.net:9696
- **Jellyseerr**: http://media-services.discus-moth.ts.net:5055
- **qBittorrent**: http://download-clients.discus-moth.ts.net:8080
- **SABnzbd**: http://download-clients.discus-moth.ts.net:8081
- **Jellyfin**: http://jellyfin.discus-moth.ts.net:8096

Via Local Network:

- Replace `.discus-moth.ts.net` with IP addresses (see [Service Endpoints](configuration/service-endpoints.md))

## Next Steps

### Configure Media Services

1. **Set up Prowlarr** - Add indexers
2. **Configure Download Clients** in Sonarr/Radarr:
   - qBittorrent: `download-clients.discus-moth.ts.net:8080`
   - SABnzbd: `download-clients.discus-moth.ts.net:8081`
3. **Add Media Libraries** in Jellyfin: `/mnt/data/media/{tv,movies}`

See [Phase 3: Services Deployment](deployment/phase3-services.md) for detailed configuration.

### Storage and NFS

The Btrfs NAS with NFS exports is automatically configured during Phase 2 deployment. All media services use shared NFS
storage at `/mnt/data` with the following structure:

- `/mnt/data/media/tv` - TV shows
- `/mnt/data/media/movies` - Movies
- `/mnt/data/downloads` - Download staging area

See [Phase 2: Networking Guide](deployment/phase2-networking.md) for NAS and NFS configuration details.

## Troubleshooting

### Can't connect to VMs

- Check Tailscale is running on your workstation
- Verify VMs are powered on: `qm status <vmid>`
- Try direct IP access instead of Tailscale hostname

### Playbook fails

- Check Proxmox credentials in group_vars/all.sops.yaml
- Verify network connectivity to Proxmox host
- Review error messages for specific task failures

### Services not accessible

- Check firewall status: `sudo ufw status`
- Verify containers are running: `systemctl --user status sonarr`
- Check service logs: `journalctl --user -u sonarr -f`

See [Troubleshooting Guide](maintenance/troubleshooting.md) for more solutions.

## Common Commands

```bash
# Check VM status
ansible all -m ping

# View container services (via SSH)
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl --user status sonarr radarr prowlarr"

# Restart a service
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl --user restart sonarr"

# Power management
ansible-playbook power-management.yml -e power_action=shutdown
```

## What's Next?

- **[Architecture](architecture.md)** - Understand the infrastructure design
- **[Deployment Guides](deployment/initial-setup.md)** - Detailed deployment documentation
- **[Configuration](configuration/service-endpoints.md)** - Service configuration guides
- **[Maintenance](maintenance/updates.md)** - Ongoing maintenance procedures

## Need Help?

- Review [Troubleshooting Guide](maintenance/troubleshooting.md)
- Check playbook output for error messages
- Verify all prerequisites are met
- Consult detailed guides in [deployment/initial-setup.md](deployment/initial-setup.md)
