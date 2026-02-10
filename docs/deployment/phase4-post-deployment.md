# Phase 4: Security Hardening

Apply security hardening and final configuration.

## Overview

Phase 4 applies Recyclarr configuration (using API keys from secrets file), enables firewall restrictions, and configures
automatic security updates.

**Estimated Time**: 3-5 minutes

## Prerequisites

- ✅ Phase 3 completed (all services deployed)
- ✅ Manual configuration completed:
  - Sonarr and Radarr API keys retrieved
  - API keys added to secrets file
  - Download clients configured in Prowlarr/Sonarr/Radarr
  - Indexers added to Prowlarr

## What Phase 4 Does

### 1. Recyclarr Configuration

- Configures Recyclarr with TRaSH Guides
- Uses Sonarr/Radarr API keys from secrets file
- Applies custom formats for quality
- Configures quality profiles
- Syncs configuration to Sonarr and Radarr

### 2. UFW Firewall

- Enables UFW firewall on all VMs
- **SSH from Tailscale + local network** (LAN fallback for outages)
- Allows service ports from local network + Tailscale
- External access blocked (only Tailscale and LAN allowed)

### 3. Unattended Upgrades

- Configures automatic security updates
- Installs updates from security repositories
- Configures auto-reboot if required (optional)
- Keeps systems patched

## Running Phase 4

⚠️ **IMPORTANT**: Complete manual configuration FIRST!

See [post-deployment.md](post-deployment.md) for manual steps.

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

## Expected Output

```text
PLAY [Configure Recyclarr] *********************************************

TASK [Sync Recyclarr configuration] ************************************
changed: [media-services]

PLAY [Configure UFW Firewall] ******************************************

TASK [Enable UFW firewall] *********************************************
changed: [home-assistant]
changed: [nas]
changed: [jellyfin]
changed: [media-services]
changed: [download-clients]
changed: [satisfactory-server]

PLAY [Configure Unattended Upgrades] ***********************************

TASK [Install unattended-upgrades] *************************************
changed: [all VMs]

PLAY RECAP *************************************************************
media-services       : ok=8  changed=6
home-assistant       : ok=5  changed=4
nas                  : ok=5  changed=4
jellyfin             : ok=5  changed=4
download-clients     : ok=5  changed=4
satisfactory-server  : ok=5  changed=4
```

## Verification

### Check Recyclarr Sync

```bash
# Check Recyclarr logs
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker logs recyclarr"
```

Expected: Successful sync messages

### Verify Custom Formats in Sonarr

1. Access Sonarr: http://media-services.discus-moth.ts.net:8989
2. Navigate to **Settings** → **Profiles**
3. Check that custom formats are present (TRaSH Guides formats)

### Verify Custom Formats in Radarr

1. Access Radarr: http://media-services.discus-moth.ts.net:7878
2. Navigate to **Settings** → **Profiles**
3. Check that custom formats are present

### Check UFW Firewall Status

```bash
# Check firewall on media services
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw status"
```

Expected output:

```text
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       100.64.0.0/10  # SSH (Tailscale)
8989/tcp                   ALLOW       Anywhere       # Sonarr
7878/tcp                   ALLOW       Anywhere       # Radarr
...
```

### Test SSH Restrictions

```bash
# This should work (Tailscale hostname):
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# This should be BLOCKED (IP address):
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.13
# Expected: Connection timeout or "Connection refused"
```

### Verify Unattended Upgrades

```bash
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl status unattended-upgrades"
```

Expected: `Active: active (running)`

## Access Notes

### SSH Access

SSH is accessible from both networks (LAN fallback for Tailscale outages):

**Via Tailscale** (preferred):

```bash
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net
```

**Via Local Network** (fallback):

```bash
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.13
ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.12
```

### Service Access

Web services accessible from:

- **Local network** (192.168.0.0/24)
- **Tailscale network** (100.64.0.0/10)

Services like Sonarr, Radarr, Jellyfin are accessible via browser from both networks.

### Security Model

- **Protection**: No direct access from internet (external blocked)
- **Convenience**: Full access from Tailscale and local network
- **Resilience**: LAN fallback ensures access during Tailscale outages

## Troubleshooting

### Recyclarr Fails to Sync

**Error**: `Failed to authenticate with Sonarr/Radarr`

**Solution**:

```bash
# Verify API keys in secrets file
sops -d group_vars/all.sops.yaml | grep api_key

# Check Sonarr/Radarr are accessible
curl -I http://media-services.discus-moth.ts.net:8989
curl -I http://media-services.discus-moth.ts.net:7878

# Check Recyclarr config
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker exec recyclarr cat /config/recyclarr.yml"

# Manually sync
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "docker exec recyclarr recyclarr sync"
```

### Locked Out After Firewall Enable

**Error**: Can't SSH to VMs

**Solution**:

```bash
# Use Tailscale hostname, not IP
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# If Tailscale isn't working on your workstation:
tailscale status  # Check if connected

# Emergency: Access via Proxmox console
ssh root@jellybuntu.discus-moth.ts.net
qm terminal <vmid>
# Login and temporarily disable firewall:
sudo ufw disable
```

### Firewall Won't Enable

**Error**: `Failed to enable UFW`

**Solution**:

```bash
# Check UFW installation
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "which ufw"

# Check firewall rules
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw show added"

# Manually enable
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw --force enable"
```

### Unattended Upgrades Not Working

**Solution**:

```bash
# Check service status
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "systemctl status unattended-upgrades"

# View logs
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo cat /var/log/unattended-upgrades/unattended-upgrades.log"

# Manually trigger
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo unattended-upgrade --debug"
```

### Services Not Accessible After Firewall

**Error**: Can't access web UIs

**Solution**:

```bash
# Check UFW rules for service ports
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw status numbered"

# Ensure service ports are allowed
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
  "sudo ufw allow 8989/tcp comment 'Sonarr'"

# Check from which network you're accessing:
# - Local network (192.168.0.x): Should work
# - Tailscale (100.x.x.x): Should work
# - Public internet: Won't work (by design)
```

## Playbook Details

**Files**:

- [`playbooks/services/recyclarr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/recyclarr.yml) - Recyclarr configuration
- [`playbooks/system/system-hardening.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/system/system-hardening.yml) - Firewall setup + auto-updates

**Roles**:

- [`roles/recyclarr/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/recyclarr/) - Recyclarr TRaSH Guides sync
- [`roles/ufw_firewall/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/ufw_firewall/) - UFW firewall configuration
- [`roles/unattended_upgrades/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/unattended_upgrades/) - Automatic security updates

**Variables**:

- `vault_sonarr_api_key`: Sonarr API key (from manual config)
- `vault_radarr_api_key`: Radarr API key (from manual config)
- `firewall_ports`: Per-VM port configuration
- `tailscale_network`: Tailscale CIDR (100.64.0.0/10)

## Firewall Rules

Each VM has custom firewall rules:

### Media Services (401)

- SSH: Tailscale + LAN
- 8989 (Sonarr): Local + Tailscale
- 7878 (Radarr): Local + Tailscale
- 9696 (Prowlarr): Local + Tailscale
- 5055 (Jellyseerr): Local + Tailscale
- 8191 (Byparr): Localhost only

### Download Clients (402)

- SSH: Tailscale + LAN
- 8080 (qBittorrent): Local + Tailscale
- 8081 (SABnzbd): Local + Tailscale
- 6881 (qBittorrent incoming): Allow all

### Jellyfin (400)

- SSH: Tailscale + LAN
- 8096 (Jellyfin): Local + Tailscale

### NAS (300)

- SSH: Tailscale + LAN
- 2049 (NFS): Local network only

See [`host_vars/<vm>.yml`](https://github.com/SilverDFlame/jellybuntu/tree/main/host_vars) for complete firewall rules per VM.

## What Recyclarr Configures

Recyclarr applies TRaSH Guides recommendations:

**Custom Formats**:

- Release group preferences
- Unwanted formats (cam, hardcoded subs, etc.)
- Preferred codecs (x265, AV1)
- HDR formats
- Audio quality preferences

**Quality Profiles**:

- Minimum/maximum quality settings
- Upgrade preferences
- Custom format scoring

See: https://trash-guides.info for details on what Recyclarr configures.

## Re-Running Phase 4

Phase 4 is idempotent:

```bash
# Safe to re-run
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

Re-running will:

- Re-sync Recyclarr (updates custom formats)
- Re-apply firewall rules (safe)
- Re-configure unattended upgrades (safe)

## Success Criteria

✅ Phase 4 is complete when:

- [ ] Recyclarr synced successfully
- [ ] Custom formats visible in Sonarr/Radarr
- [ ] UFW firewall active on all VMs
- [ ] SSH via IP blocked, Tailscale works
- [ ] Unattended upgrades enabled
- [ ] All services still accessible via web

## Deployment Complete

🎉 All phases finished! Your homelab is fully deployed and secured.

### What You Have Now

- ✅ 6 VMs provisioned and configured
- ✅ Btrfs RAID1 NAS with NFS
- ✅ Tailscale VPN mesh network
- ✅ Media automation (Sonarr, Radarr, Prowlarr)
- ✅ Download clients (qBittorrent, SABnzbd)
- ✅ Media server (Jellyfin)
- ✅ Home automation (Home Assistant)
- ✅ Game server (Satisfactory)
- ✅ Quality profiles (TRaSH Guides via Recyclarr)
- ✅ Security hardening (firewall, auto-updates)

### Next Steps

1. **Configure Jellyseerr**: Link to Jellyfin and media services
2. **Add Media Libraries**: Configure Jellyfin libraries
3. **Test Automation**: Request content in Jellyseerr, verify download
4. **Customize**: Adjust quality profiles, add indexers
5. **Monitor**: Check logs, verify everything works

### Recommended Reading

- [Post-Deployment Guide](post-deployment.md) - Additional configuration
- [Maintenance Guide](../maintenance/updates.md) - Keeping services updated
- [Troubleshooting](../troubleshooting/common-issues.md) - Common issues
- [Architecture](../architecture.md) - Understanding your infrastructure

## Reference

- [Phase-Based Deployment](phase-based-deployment.md) - All phases overview
- [Initial Setup Guide](initial-setup.md) - Complete setup walkthrough
- [Security Configuration](../configuration/security.md) - Security details
- [Firewall Configuration](../configuration/networking.md) - Network security
- [TRaSH Guides](https://trash-guides.info) - Quality profiles reference
